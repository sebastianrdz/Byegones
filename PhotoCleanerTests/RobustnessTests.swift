import AVFoundation
import Foundation
import Testing
import UIKit
@testable import PhotoCleaner

private struct Boom: Error {}

@Suite("Progress file robustness")
struct ProgressFileRobustnessTests {
    private func write(_ text: String, to store: ProgressStore) throws {
        try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: store.fileURL)
    }

    private func quarantined(_ store: ProgressStore) throws -> [String] {
        try store.quarantinedFileURLs.map { try String(contentsOf: $0, encoding: .utf8) }
    }

    @Test func corruptFileIsMovedAsideNotOverwritten() async throws {
        let store = Fixture.tempStore()
        try write("not json at all", to: store)

        #expect(store.load() == ProgressData())
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        #expect(try quarantined(store) == ["not json at all"])
        let name = try #require(store.quarantinedFileURLs.first?.lastPathComponent)
        #expect(name.hasPrefix("progress.corrupt-") && name.hasSuffix(".json"))

        // A later save writes a fresh file and leaves the evidence alone.
        try store.save(ProgressData(reviewedIDs: ["a"]))
        #expect(store.load().reviewedIDs == ["a"])
        #expect(try quarantined(store) == ["not json at all"])
    }

    @Test func aSecondCorruptionKeepsTheFirstQuarantinedCopy() throws {
        let store = Fixture.tempStore()
        try write("first", to: store)
        _ = store.load()
        try write("second", to: store)
        _ = store.load()
        // Newest first; the first copy is still there.
        let kept = try quarantined(store)
        #expect(kept == ["second", "first"])
    }

    @Test func onlyTheLastThreeQuarantinedCopiesAreKept() throws {
        let store = Fixture.tempStore()
        for n in 1...5 {
            try write("copy-\(n)", to: store)
            _ = store.load()
        }
        let kept = try quarantined(store)
        #expect(kept == ["copy-5", "copy-4", "copy-3"])
    }

    @Test func missingFileLoadsEmptyAndQuarantinesNothing() {
        let store = Fixture.tempStore()
        #expect(store.load() == ProgressData())
        #expect(store.quarantinedFileURLs.isEmpty)
    }

    @Test func ifTheFileCannotBeMovedAsideSavingIsRefusedAndTheOriginalSurvives() async throws {
        struct NoMove: Error {}
        let base = Fixture.tempStore()
        let store = ProgressStore(fileURL: base.fileURL, move: { _, _ in throw NoMove() })
        try write("unreadable original", to: store)

        #expect(store.load() == ProgressData())
        #expect(throws: ProgressStore.StoreError.unreadableFileKept) { try store.save(ProgressData(reviewedIDs: ["x"])) }
        #expect(try String(contentsOf: store.fileURL, encoding: .utf8) == "unreadable original")

        // Through a session: the failed save is logged, the file stays.
        let library = FakePhotoLibrary(items: [MediaItem(id: "0"), MediaItem(id: "1")])
        let session = SwipeSession(library: library, store: store)
        await session.load()
        session.keep()
        await session.flush()
        #expect(try String(contentsOf: store.fileURL, encoding: .utf8) == "unreadable original")
    }

    @Test func sessionStartedOnCorruptFileKeepsTheBadFileAfterSaving() async throws {
        let store = Fixture.tempStore()
        try write("garbage", to: store)
        let library = FakePhotoLibrary(items: [MediaItem(id: "0"), MediaItem(id: "1")])
        let session = SwipeSession(library: library, store: store)
        await session.load()
        session.keep()
        await session.flush()
        #expect(store.load().reviewedIDs == ["0"])
        #expect(try quarantined(store) == ["garbage"])
    }

    @Test(arguments: ["{}", #"{"reviewed":["a"],"pending":["b"],"freed":5}"#, #"{"futureField":{"x":1}}"#])
    func aFileWithNoRecognisedKeysIsQuarantinedNotTreatedAsEmptyProgress(json: String) throws {
        let store = Fixture.tempStore()
        try write(json, to: store)
        #expect(store.load() == ProgressData())
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        #expect(try quarantined(store) == [json])
    }

    @Test(arguments: [
        (#"{"reviewedIDs":["a"]}"#, ProgressData(reviewedIDs: ["a"])),
        (#"{"pendingTrashIDs":["p","q"]}"#, ProgressData(pendingTrashIDs: ["p", "q"])),
        (#"{"bytesFreed":99}"#, ProgressData(bytesFreed: 99)),
        (#"{"reviewedIDs":["a"],"bytesFreed":5,"futureField":1}"#, ProgressData(reviewedIDs: ["a"], bytesFreed: 5)),
    ])
    func missingIndividualKeysDecodeToDefaultsWithoutLosingTheRest(json: String, expected: ProgressData) throws {
        let store = Fixture.tempStore()
        try write(json, to: store)
        #expect(store.load() == expected)
        #expect(store.quarantinedFileURLs.isEmpty)
    }
}

@Suite("Pile survives short fetches")
struct PileSurvivalTests {
    @Test func limitedAccessKeepsAPileIDThatTheFetchDidNotReturn() async {
        let f = await Fixture.make()
        f.session.trash()   // "0"
        f.session.trash()   // "1"
        await f.session.flush()

        f.library.accessLevel = .limited
        f.library.hiddenFromFetch = ["1"]
        await f.session.load()

        // Not shown (Photos did not return it), but never forgotten.
        #expect(f.session.pendingTrash.map(\.id) == ["0"])
        await f.session.flush()
        #expect(f.store.load().pendingTrashIDs == ["0", "1"])

        // The selection grows again: the item comes back in its place.
        f.library.hiddenFromFetch = []
        await f.session.load()
        #expect(f.session.pendingTrash.map(\.id).sorted() == ["0", "1"])
    }

    @Test func fullAccessKeepsAnIDThatPhotosStillHasEvenIfTheFetchMissedIt() async {
        let f = await Fixture.make()
        f.session.trash()
        await f.session.flush()
        f.library.hiddenFromFetch = ["0"]   // transient short fetch; the asset still exists
        await f.session.load()
        #expect(f.session.pendingTrash.isEmpty)
        #expect(f.store.load().pendingTrashIDs == ["0"])
        f.library.hiddenFromFetch = []
        await f.session.load()
        #expect(f.session.pendingTrash.map(\.id) == ["0"])
    }

    @Test func fullAccessPrunesAnIDOnlyWhenPhotosConfirmsItIsGone() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        await f.session.flush()
        f.library.items.removeAll { $0.id == "0" }
        await f.session.load()
        #expect(f.session.pendingTrash.map(\.id) == ["1"])
        await f.session.flush()
        #expect(f.store.load().pendingTrashIDs == ["1"])
    }

    @Test func limitedAccessNeverPrunesEvenWhenTheAssetIsReallyGone() async {
        let f = await Fixture.make()
        f.session.trash()
        await f.session.flush()
        f.library.accessLevel = .limited
        f.library.items.removeAll { $0.id == "0" }
        await f.session.load()
        #expect(f.store.load().pendingTrashIDs == ["0"])
    }

    @Test func unresolvedPileItemsAreNotSentToDelete() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.library.hiddenFromFetch = ["1"]
        f.library.accessLevel = .limited
        await f.session.load()
        _ = await f.session.commitTrash()
        #expect(f.library.deleteCalls == [["0"]])
        await f.session.flush()
        #expect(f.store.load().pendingTrashIDs == ["1"])
    }

    @Test func reviewedIDsAreNeverPrunedByLoad() async {
        let f = await Fixture.make()
        f.session.keep()
        await f.session.flush()
        f.library.items.removeAll { $0.id == "0" }
        await f.session.load()
        #expect(f.session.reviewedIDs == ["0"])
        #expect(f.store.load().reviewedIDs == ["0"])
    }
}

@Suite("Deleted-item accounting")
struct DeletedAccountingTests {
    @Test func onlyItemsThatActuallyExistedAreCounted() async {
        let f = await Fixture.make()
        f.session.trash()   // "0"
        f.session.trash()   // "1"
        f.library.items.removeAll { $0.id == "1" }   // deleted elsewhere after the pile was built
        let outcome = await f.session.commitTrash()
        guard case .deleted(let count, let bytes) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 1)
        #expect(bytes == 100)
        #expect(f.session.bytesFreed == 100)
        #expect(f.session.pendingTrash.isEmpty)
    }

    @Test func aPileOfOnlyVanishedItemsClearsWithoutCelebratingAnything() async {
        let f = await Fixture.make()
        f.session.trash()
        f.library.items.removeAll { $0.id == "0" }
        let outcome = await f.session.commitTrash()
        guard case .nothingToDelete = outcome else {
            Issue.record("expected .nothingToDelete, got \(outcome)")
            return
        }
        #expect(f.session.bytesFreed == 0)
        #expect(f.session.pendingTrash.isEmpty)
    }
}

@Suite("Commit guards")
struct CommitGuardTests {
    @Test func untrashAndRestoreAreIgnoredWhileCommitting() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        let first = f.session.pendingTrash[0]
        let gate = Gate()
        f.library.beforeDelete = { _ in await gate.wait() }

        async let commit = f.session.commitTrash()
        await gate.untilWaiting()
        #expect(f.session.isCommitting)
        #expect(!f.session.canUndo)
        f.session.untrash(first.id)
        f.session.restoreToTrash(first, at: 0)
        f.session.undo()
        #expect(f.session.pendingTrash.map(\.id) == ["0", "1"])
        #expect(f.session.history.count == 2)
        gate.open()
        _ = await commit
        #expect(f.library.deleteCalls == [["0", "1"]])
        #expect(f.session.pendingTrash.isEmpty)
    }
}

@Suite("Rescue then delete")
struct RescueThenDeleteTests {
    /// The trash sheet untrashes the moment a cell is tapped, so a Delete tapped right after
    /// batches exactly what is left in the pile.
    @Test func anItemRescuedJustBeforeDeleteIsNotInTheBatch() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.session.trash()
        f.session.untrash("1")
        async let commit = f.session.commitTrash()
        let outcome = await commit
        guard case .deleted(let count, _) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 2)
        #expect(f.library.deleteCalls == [["0", "2"]])
        #expect(f.library.items.map(\.id).contains("1"))
    }

    @Test func aRescueAfterTheBatchWasCapturedIsRefusedSoNothingClaimsToHaveRescuedIt() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        let gate = Gate()
        f.library.beforeDelete = { _ in await gate.wait() }
        async let commit = f.session.commitTrash()
        await gate.untilWaiting()
        // The view disables the cells while deleting, and the session refuses as a backstop.
        let before = f.session.pendingTrash.map(\.id)
        f.session.untrash("0")
        #expect(f.session.pendingTrash.map(\.id) == before)
        #expect(!f.session.reviewedIDs.contains("0"))
        gate.open()
        _ = await commit
        #expect(f.library.deleteCalls == [["0", "1"]])
    }
}

@Suite("Reload coalescing")
struct ReloadCoalescingTests {
    @Test func reloadsRequestedDuringALoadRunExactlyOneMoreLoad() async {
        let f = await Fixture.make()
        let gate = Gate()
        f.library.beforeFetch = { await gate.wait() }
        let base = f.library.fetchCount

        async let first: Void = f.session.load()
        await gate.untilWaiting()
        // Three triggers while the load is running (picker, foreground, reloadIfNeeded).
        f.library.items.insert(MediaItem(id: "late"), at: 0)
        f.library.changeRevision += 1
        await f.session.load()
        await f.session.load()
        await f.session.reloadIfNeeded()
        gate.open()
        await first

        #expect(f.library.fetchCount == base + 2)   // the running load plus exactly one more
        #expect(f.session.queue.first?.id == "late")
    }

    @Test func resetProgressDuringALoadStillReloadsAfterward() async {
        let f = await Fixture.make()
        f.session.keep()
        let gate = Gate()
        f.library.beforeFetch = { await gate.wait() }
        async let running: Void = f.session.load()
        await gate.untilWaiting()
        async let reset: Void = f.session.resetProgress()
        gate.open()
        _ = await (running, reset)
        #expect(f.session.reviewedIDs.isEmpty)
        #expect(f.session.queue.map(\.id) == ["0", "1", "2", "3", "4"])
    }
}

@Suite("Failed favorite")
struct FailedFavoriteTests {
    @Test func failedFavoritePostsANoticeAndBecomesAPlainKeep() async {
        let f = await Fixture.make()
        f.library.favoriteError = Boom()
        f.session.favorite()
        await f.session.flush()
        #expect(f.session.notice?.kind == .favoriteFailed)
        #expect(f.session.history.map(\.action) == [.keep])
        #expect(f.session.reviewedIDs == ["0"])
    }

    @Test func undoingADowngradedFavoriteDoesNotQueueAWriteThatCannotSucceed() async {
        let f = await Fixture.make()
        f.library.favoriteError = Boom()
        f.session.favorite()
        await f.session.flush()
        f.library.favoriteError = nil
        f.session.undo()
        await f.session.flush()
        #expect(f.library.favoriteCalls.map(\.value) == [true])   // no setFavorite(false)
        #expect(f.session.current?.id == "0")
    }

    @Test func eachFailureIsANewNotice() async {
        let f = await Fixture.make()
        f.library.favoriteError = Boom()
        f.session.favorite()
        await f.session.flush()
        let first = f.session.notice
        f.session.favorite()
        await f.session.flush()
        #expect(f.session.notice != first)
        f.session.dismissNotice()
        #expect(f.session.notice == nil)
    }

    @Test func aFailedRevertIsReportedAsSuch() async {
        let f = await Fixture.make()
        f.session.favorite()
        await f.session.flush()
        f.library.favoriteError = Boom()
        f.session.undo()
        await f.session.flush()
        #expect(f.session.notice?.kind == .unfavoriteFailed)
    }

    @Test func successfulFavoritePostsNoNotice() async {
        let f = await Fixture.make()
        f.session.favorite()
        await f.session.flush()
        #expect(f.session.notice == nil)
    }
}

@Suite("Size lookups and reloads")
struct SizeAndReloadTests {
    @Test func unknownSizeIsLookedUpOnlyOnce() async {
        let library = FakePhotoLibrary(items: [MediaItem(id: "0")])   // no size registered
        let session = SwipeSession(library: library, store: Fixture.tempStore())
        await session.load()
        let item = MediaItem(id: "0")
        for _ in 0..<50 { #expect(session.byteSize(of: item) == nil) }
        #expect(library.byteSizeCalls == 1)
    }

    @Test func knownSizeIsLookedUpOnlyOnce() async {
        let f = await Fixture.make()
        let item = MediaItem(id: "0")
        for _ in 0..<50 { #expect(f.session.byteSize(of: item) == 100) }
        #expect(f.library.byteSizeCalls == 1)
    }

    @Test func reloadIfNeededSkipsTheFetchWhenNothingChanged() async {
        let f = await Fixture.make()
        let before = f.library.fetchCount
        await f.session.reloadIfNeeded()
        #expect(f.library.fetchCount == before)
    }

    @Test func reloadIfNeededFetchesAfterAChangeNotification() async {
        let f = await Fixture.make()
        f.library.items.insert(MediaItem(id: "new"), at: 0)
        f.library.changeRevision += 1
        await f.session.reloadIfNeeded()
        #expect(f.session.queue.first?.id == "new")
        let after = f.library.fetchCount
        await f.session.reloadIfNeeded()
        #expect(f.library.fetchCount == after)
    }

    @Test func reloadIfNeededFetchesWhenAccessChanged() async {
        let f = await Fixture.make()
        f.library.accessLevel = .limited
        let before = f.library.fetchCount
        await f.session.reloadIfNeeded()
        #expect(f.library.fetchCount == before + 1)
        #expect(f.session.access == .limited)
    }
}

@Suite("Access answer")
struct AccessAnswerTests {
    /// `authorizationStatus` can keep reporting "not determined" for a moment after the system
    /// prompt was answered. The answer to our own request must win meanwhile.
    final class LaggingStatus: PhotoLibraryProviding {
        let inner = FakePhotoLibrary(items: [MediaItem(id: "0")])
        let answer: LibraryAccess
        init(answer: LibraryAccess) { self.answer = answer }
        var accessLevel: LibraryAccess { .notDetermined }
        func requestAuthorization() async -> LibraryAccess { answer }
        func fetchItems() async -> [MediaItem] { await inner.fetchItems() }
        func image(for id: String, targetSize: CGSize) async -> UIImage? { nil }
        func playerItem(for id: String) async -> AVPlayerItem? { nil }
        func startCaching(ids: [String], targetSize: CGSize) {}
        func stopCaching() {}
        func setFavorite(_ isFavorite: Bool, forID id: String) async throws {}
        func delete(ids: [String]) async throws -> [String] { ids }
        func byteSize(for id: String) -> Int64? { nil }
    }

    @Test func deniedAnswerIsNotOverwrittenByAStaleNotDeterminedStatus() async {
        let session = SwipeSession(library: LaggingStatus(answer: .denied), store: Fixture.tempStore())
        await session.start()
        #expect(session.access == .denied)
        await session.load()
        #expect(session.access == .denied)
        await session.reloadIfNeeded()
        #expect(session.access == .denied)
    }

    @Test func grantedAnswerLoadsTheLibraryDespiteAStaleStatus() async {
        let session = SwipeSession(library: LaggingStatus(answer: .authorized), store: Fixture.tempStore())
        await session.start()
        #expect(session.access == .authorized)
        #expect(session.current?.id == "0")
    }
}

@Suite("Leaver watchdog")
struct LeaverWatchdogTests {
    /// Without a window there may be no animation completion at all (the same situation as a lost
    /// completion on screen). The watchdog must still remove the leaver, and must not disturb the
    /// state the decision already produced.
    @Test func aLeaverNeverOutlivesTheWatchdog() async throws {
        let f = await Fixture.make()
        let controller = CardController(session: f.session)
        controller.perform(.keep)
        try await Task.sleep(for: .milliseconds(300))
        #expect(f.session.current?.id == "1")   // the decision itself was applied immediately
        try await Task.sleep(for: .milliseconds(1700))
        #expect(controller.leavers.isEmpty)
        #expect(f.session.reviewedIDs == ["0"])
        #expect(f.session.current?.id == "1")
    }

    @Test func theWatchdogOfAnOlderFlightDoesNotRemoveANewerLeaverOfTheSameCard() async throws {
        let f = await Fixture.make()
        let controller = CardController(session: f.session)
        controller.perform(.keep)
        try await Task.sleep(for: .milliseconds(200))
        controller.undo()
        try await Task.sleep(for: .milliseconds(200))
        controller.perform(.trash)           // the same card flies out again
        try await Task.sleep(for: .milliseconds(1400))
        // The first flight's watchdog has fired by now; it must not have touched the second one's
        // bookkeeping, and everything is gone once the second flight's own watchdog has fired.
        try await Task.sleep(for: .milliseconds(900))
        #expect(controller.leavers.isEmpty)
        #expect(f.session.pendingTrash.map(\.id) == ["0"])
    }
}

@Suite("Background flush")
struct BackgroundFlushTests {
    final class Counter { var finished = 0 }

    /// Each run owns its background task. Overlapping runs (background, foreground, background
    /// again) must each finish their work without one ending the other's time.
    @Test func overlappingRunsEachCompleteTheirOwnWork() async {
        let flush = BackgroundFlush()
        let counter = Counter()
        let gate = Gate()
        flush.run { await gate.wait(); counter.finished += 1 }
        flush.run { await gate.wait(); counter.finished += 1 }
        flush.run { counter.finished += 1 }   // finishes first, while the others are still running
        await gate.untilWaiting()
        #expect(counter.finished == 1)
        gate.open()
        for _ in 0..<200 where counter.finished < 3 { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(counter.finished == 3)
    }
}
