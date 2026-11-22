import Foundation
import Testing
@testable import PhotoCleaner

@Suite("ProgressStore file handling")
struct ProgressStoreTests {
    @Test func missingFileLoadsEmptyWithoutCreatingIt() {
        let store = Fixture.tempStore()
        #expect(store.load() == ProgressData())
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    @Test func saveCreatesMissingIntermediateDirectories() throws {
        let nested = FileManager.default.temporaryDirectory
            .appending(path: "PCT-\(UUID().uuidString)/a/b/c", directoryHint: .isDirectory)
            .appending(path: "progress.json", directoryHint: .notDirectory)
        let store = ProgressStore(fileURL: nested)
        let data = ProgressData(reviewedIDs: ["x"], pendingTrashIDs: ["y"], bytesFreed: 9)
        try store.save(data)
        #expect(store.load() == data)
    }

    @Test func roundTripPreservesIDsWithUnusualCharactersAndOrder() throws {
        let store = Fixture.tempStore()
        let pending = ["B84E8479-475C-4727-A4A4-B77AA9980897/L0/001", "ünï/çödé \"quoted\"", "", "z", "a"]
        let data = ProgressData(reviewedIDs: Set(pending), pendingTrashIDs: pending, bytesFreed: Int64.max)
        try store.save(data)
        let loaded = store.load()
        #expect(loaded == data)
        #expect(loaded.pendingTrashIDs == pending)   // order is meaningful (oldest first)
    }

    @Test func saveOverwritesPreviousContents() throws {
        let store = Fixture.tempStore()
        try store.save(ProgressData(reviewedIDs: ["a", "b", "c"], pendingTrashIDs: ["p"], bytesFreed: 10))
        try store.save(ProgressData(reviewedIDs: ["a"], pendingTrashIDs: [], bytesFreed: 20))
        #expect(store.load() == ProgressData(reviewedIDs: ["a"], pendingTrashIDs: [], bytesFreed: 20))
    }

    @Test(arguments: [
        "",                                   // empty file
        "{",                                  // truncated JSON
        "[]",                                 // wrong top-level type
        "{\"reviewedIDs\": 5}",               // wrong value type
        "null",
    ])
    func unreadableContentsLoadAsEmpty(_ contents: String) throws {
        let store = Fixture.tempStore()
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: store.fileURL)
        #expect(store.load() == ProgressData())
    }

    @Test func binaryGarbageLoadsAsEmpty() throws {
        let store = Fixture.tempStore()
        try store.save(ProgressData(bytesFreed: 1))
        try Data((0..<256).map { UInt8($0) }).write(to: store.fileURL)
        #expect(store.load() == ProgressData())
    }

    @Test func unknownExtraKeysAreIgnored() throws {
        let store = Fixture.tempStore()
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let json = #"{"reviewedIDs":["a"],"pendingTrashIDs":["b"],"bytesFreed":3,"futureField":{"x":1}}"#
        try Data(json.utf8).write(to: store.fileURL)
        #expect(store.load() == ProgressData(reviewedIDs: ["a"], pendingTrashIDs: ["b"], bytesFreed: 3))
    }

    @Test func saveToUnwritableLocationThrowsAndLeavesNoFile() throws {
        // A regular file where a directory is required.
        let blocker = FileManager.default.temporaryDirectory.appending(path: "PCT-blocker-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        let store = ProgressStore(fileURL: blocker.appending(path: "progress.json", directoryHint: .notDirectory))
        #expect(throws: (any Error).self) { try store.save(ProgressData(bytesFreed: 1)) }
        #expect(store.load() == ProgressData())
    }

    @Test func saveInBackgroundWritesTheSameFile() async throws {
        let store = Fixture.tempStore()
        let data = ProgressData(reviewedIDs: ["a"], pendingTrashIDs: ["b"], bytesFreed: 42)
        try await store.saveInBackground(data)
        #expect(store.load() == data)
    }

    @Test func defaultLocationIsProgressJSONInApplicationSupport() {
        let url = ProgressStore.defaultFileURL
        #expect(url.lastPathComponent == "progress.json")
        #expect(url.deletingLastPathComponent().standardizedFileURL == URL.applicationSupportDirectory.standardizedFileURL)
    }
}

@Suite("Session persistence behavior")
struct SessionPersistenceTests {
    @Test func sessionStartsEmptyOnCorruptFileAndOverwritesItOnFirstDecision() async throws {
        let store = Fixture.tempStore()
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: store.fileURL)
        let library = FakePhotoLibrary(items: (0..<3).map { MediaItem(id: "\($0)") })
        let session = SwipeSession(library: library, store: store)
        await session.load()
        #expect(session.queue.count == 3)
        #expect(session.bytesFreed == 0)
        session.keep()
        await session.flush()
        #expect(store.load().reviewedIDs == ["0"])
    }

    @Test func burstOfSwipesCoalescesButTheLastStateAlwaysWins() async {
        let f = await Fixture.make(count: 500)
        for i in 0..<500 {
            if i.isMultiple(of: 5) { f.session.trash() } else { f.session.keep() }
        }
        await f.session.flush()
        let saved = f.store.load()
        #expect(saved.reviewedIDs.count == 400)
        #expect(saved.pendingTrashIDs.count == 100)
        #expect(saved.pendingTrashIDs.first == "0")
        #expect(saved.pendingTrashIDs.last == "495")
    }

    @Test func undoIsPersistedToo() async {
        let f = await Fixture.make()
        f.session.keep()
        f.session.trash()
        f.session.undo()
        f.session.undo()
        await f.session.flush()
        #expect(f.store.load() == ProgressData())
    }

    @Test func deniedAccessNeverForgetsASavedPileEvenAfterResetProgress() async throws {
        let store = Fixture.tempStore()
        try store.save(ProgressData(reviewedIDs: ["r"], pendingTrashIDs: ["p1", "p2"], bytesFreed: 5))
        let library = FakePhotoLibrary(items: [MediaItem(id: "p1"), MediaItem(id: "p2"), MediaItem(id: "r")])
        library.accessLevel = .denied
        let session = SwipeSession(library: library, store: store)
        await session.start()
        await session.resetProgress()
        await session.flush()
        let saved = store.load()
        #expect(saved.pendingTrashIDs == ["p1", "p2"])
        #expect(saved.bytesFreed == 5)
        #expect(saved.reviewedIDs.isEmpty)

        // Access comes back: the pile is restored from disk.
        library.accessLevel = .authorized
        await session.load()
        #expect(session.pendingTrash.map(\.id) == ["p1", "p2"])
        #expect(session.queue.map(\.id) == ["r"])
    }

    @Test func fullRelaunchRestoresReviewedPileBytesAndOrder() async {
        let f = await Fixture.make(count: 6)
        f.session.keep()        // 0
        f.session.trash()       // 1
        f.session.trash()       // 2
        f.session.favorite()    // 3
        f.session.trash()       // 4
        _ = await f.session.commitTrash()
        f.session.trash()       // 5
        await f.session.flush()

        let reopened = SwipeSession(library: f.library, store: f.store)
        await reopened.load()
        #expect(reopened.reviewedIDs == ["0", "3"])
        #expect(reopened.pendingTrash.map(\.id) == ["5"])
        #expect(reopened.bytesFreed == 300)
        #expect(reopened.queue.isEmpty)
        #expect(reopened.current == nil)
    }

    @Test func pendingPileOrderSurvivesRelaunchWhenLibraryOrderDiffers() async {
        let f = await Fixture.make(count: 4)
        f.session.trash()   // 0
        f.session.trash()   // 1
        f.session.trash()   // 2
        await f.session.flush()
        f.library.items.reverse()
        let reopened = SwipeSession(library: f.library, store: f.store)
        await reopened.load()
        #expect(reopened.pendingTrash.map(\.id) == ["0", "1", "2"])
    }

    @Test func untouchedReloadAfterRelaunchDoesNotRewriteTheFile() async throws {
        let f = await Fixture.make()
        f.session.keep()
        await f.session.flush()
        let before = try Data(contentsOf: f.store.fileURL)
        let attrsBefore = try FileManager.default.attributesOfItem(atPath: f.store.fileURL.path)[.modificationDate] as? Date

        let reopened = SwipeSession(library: f.library, store: f.store)
        await reopened.load()
        await reopened.flush()
        #expect(try Data(contentsOf: f.store.fileURL) == before)
        let attrsAfter = try FileManager.default.attributesOfItem(atPath: f.store.fileURL.path)[.modificationDate] as? Date
        #expect(attrsBefore == attrsAfter)
    }
}

@Suite("Scale")
struct ScaleTests {
    /// Items are generated newest first, 20 KB each. Bounds are deliberately generous so the test
    /// only fails on a complexity regression (for example something quadratic per swipe).
    @Test func fiftyThousandItemLoadAndSwipeTiming() async throws {
        let n = 50_000
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let items = (0..<n).map { i in
            MediaItem(id: "asset-\(i)/L0/001", creationDate: base.addingTimeInterval(TimeInterval(-i)), isFavorite: i % 97 == 0)
        }
        let library = FakePhotoLibrary(items: items)
        for item in items { library.sizes[item.id] = 20_000 }
        let store = Fixture.tempStore()
        let session = SwipeSession(library: library, store: store)
        let clock = ContinuousClock()

        let loadTime = await clock.measure { await session.load() }
        #expect(session.queue.count == n)
        #expect(session.totalCount == n)
        #expect(session.current?.id == "asset-0/L0/001")

        let swipes = 2_000
        let swipeTime = clock.measure {
            for i in 0..<swipes {
                switch i % 4 {
                case 0: session.trash()
                case 1: session.favorite()
                default: session.keep()
                }
            }
        }
        #expect(session.queue.count == n - swipes)
        #expect(session.pendingTrash.count == swipes / 4)

        let undoTime = clock.measure { for _ in 0..<500 { session.undo() } }
        #expect(session.queue.count == n - swipes + 500)

        let flushTime = await clock.measure { await session.flush() }
        let saved = store.load()
        #expect(saved.reviewedIDs.count + saved.pendingTrashIDs.count == swipes - 500)

        let reopened = SwipeSession(library: library, store: store)
        let reloadTime = await clock.measure { await reopened.load() }
        #expect(reopened.queue.count == n - saved.reviewedIDs.count - saved.pendingTrashIDs.count)

        let commitTime = await clock.measure { _ = await session.commitTrash() }

        print("[perf] 50k items: load=\(loadTime) swipes(\(swipes))=\(swipeTime) undo(500)=\(undoTime) flush=\(flushTime) relaunch-load=\(reloadTime) commit=\(commitTime)")
        #expect(loadTime < .seconds(10))
        #expect(swipeTime < .seconds(10))
        #expect(undoTime < .seconds(10))
        #expect(flushTime < .seconds(10))
        #expect(reloadTime < .seconds(10))
    }
}
