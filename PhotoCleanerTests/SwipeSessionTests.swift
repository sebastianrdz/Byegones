import Foundation
import Testing
@testable import PhotoCleaner

struct Fixture {
    let library: FakePhotoLibrary
    let store: ProgressStore
    let session: SwipeSession

    static func tempStore() -> ProgressStore {
        ProgressStore(fileURL: FileManager.default.temporaryDirectory
            .appending(path: "PhotoCleanerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "progress.json", directoryHint: .notDirectory))
    }

    /// Items "0"..."n-1"; each is 100 bytes.
    static func make(count: Int = 5, favorites: Set<String> = []) async -> Fixture {
        let items = (0..<count).map { MediaItem(id: "\($0)", isFavorite: favorites.contains("\($0)")) }
        let library = FakePhotoLibrary(items: items)
        for item in items { library.sizes[item.id] = 100 }
        let store = tempStore()
        let session = SwipeSession(library: library, store: store)
        await session.load()
        return Fixture(library: library, store: store, session: session)
    }
}

@Suite("SwipeSession decisions")
struct DecisionTests {
    @Test func loadBuildsQueueNewestFirstAsProvided() async {
        let f = await Fixture.make(count: 3)
        #expect(f.session.queue.map(\.id) == ["0", "1", "2"])
        #expect(f.session.current?.id == "0")
        #expect(f.session.remainingCount == 3)
        #expect(f.library.cachedIDs == ["0", "1", "2"])
    }

    @Test func keepAdvancesAndMarksReviewed() async {
        let f = await Fixture.make()
        f.session.keep()
        #expect(f.session.current?.id == "1")
        #expect(f.session.reviewedIDs == ["0"])
        #expect(f.session.history.map(\.action) == [.keep])
        #expect(f.session.pendingTrash.isEmpty)
    }

    @Test func trashAddsToOrderedPileWithSizes() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        #expect(f.session.pendingTrash.map(\.id) == ["0", "1"])
        #expect(f.session.pendingTrashBytes == 200)
        #expect(f.session.current?.id == "2")
        #expect(f.session.reviewedIDs.isEmpty)
    }

    @Test func favoriteSetsFlagInPhotosAndMarksReviewed() async {
        let f = await Fixture.make()
        f.session.favorite()
        await f.session.flush()
        #expect(f.library.isFavorite("0"))
        #expect(f.session.reviewedIDs == ["0"])
        #expect(f.session.current?.id == "1")
    }

    @Test func undoKeepRestoresCurrent() async {
        let f = await Fixture.make()
        f.session.keep()
        f.session.undo()
        #expect(f.session.current?.id == "0")
        #expect(f.session.reviewedIDs.isEmpty)
        #expect(!f.session.canUndo)
    }

    @Test func undoTrashRemovesFromPile() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.undo()
        #expect(f.session.pendingTrash.isEmpty)
        #expect(f.session.current?.id == "0")
    }

    @Test func undoFavoriteRevertsFlagInPhotos() async {
        let f = await Fixture.make()
        f.session.favorite()
        f.session.undo()
        await f.session.flush()
        #expect(!f.library.isFavorite("0"))
        #expect(f.library.favoriteCalls.map(\.value) == [true, false])
        #expect(f.session.current?.id == "0")
        #expect(f.session.reviewedIDs.isEmpty)
    }

    @Test func undoFavoriteOfAlreadyFavoriteLeavesItFavorite() async {
        let f = await Fixture.make(favorites: ["0"])
        f.session.favorite()
        f.session.undo()
        await f.session.flush()
        #expect(f.library.isFavorite("0"))
        #expect(f.library.favoriteCalls.isEmpty)
    }

    @Test func undoWalksBackThroughMixedDecisions() async {
        let f = await Fixture.make()
        f.session.keep()
        f.session.trash()
        f.session.favorite()
        f.session.undo()
        f.session.undo()
        f.session.undo()
        await f.session.flush()
        #expect(f.session.queue.map(\.id) == ["0", "1", "2", "3", "4"])
        #expect(f.session.reviewedIDs.isEmpty)
        #expect(f.session.pendingTrash.isEmpty)
        #expect(!f.library.isFavorite("2"))
    }

    @Test func undoWithEmptyHistoryIsNoOp() async {
        let f = await Fixture.make()
        f.session.undo()
        #expect(f.session.queue.count == 5)
    }

    @Test func untrashRemovesFromPileAndCountsAsKept() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.untrash("0")
        #expect(f.session.pendingTrash.isEmpty)
        #expect(f.session.reviewedIDs == ["0"])
        // Undoing the (now stale) trash decision still lands in a consistent state.
        f.session.undo()
        #expect(f.session.current?.id == "0")
        #expect(f.session.reviewedIDs.isEmpty)
    }
}

@Suite("SwipeSession commit")
struct CommitTests {
    @Test func successClearsPileAndAddsBytesFreed() async throws {
        let f = await Fixture.make()
        f.session.trash()
        f.session.keep()
        f.session.trash()
        let outcome = await f.session.commitTrash()
        guard case .deleted(let count, let bytes) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 2)
        #expect(bytes == 200)
        #expect(f.library.deleteCalls == [["0", "2"]])
        #expect(f.session.pendingTrash.isEmpty)
        #expect(f.session.bytesFreed == 200)
        #expect(f.session.history.map(\.action) == [.keep])
        await f.session.flush()
        #expect(f.store.load().bytesFreed == 200)
        #expect(f.store.load().pendingTrashIDs.isEmpty)
    }

    @Test func cancelKeepsPile() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.library.deleteError = PhotoLibraryError.userCancelled
        let outcome = await f.session.commitTrash()
        guard case .cancelled = outcome else {
            Issue.record("expected .cancelled, got \(outcome)")
            return
        }
        #expect(f.session.pendingTrash.map(\.id) == ["0", "1"])
        #expect(f.session.bytesFreed == 0)
        #expect(f.session.canUndo)
    }

    @Test func otherErrorKeepsPile() async {
        struct Boom: Error {}
        let f = await Fixture.make()
        f.session.trash()
        f.library.deleteError = Boom()
        let outcome = await f.session.commitTrash()
        guard case .failed = outcome else {
            Issue.record("expected .failed, got \(outcome)")
            return
        }
        #expect(f.session.pendingTrash.count == 1)
        #expect(f.session.bytesFreed == 0)
    }

    @Test func emptyPileDoesNotCallLibrary() async {
        let f = await Fixture.make()
        let outcome = await f.session.commitTrash()
        guard case .nothingToDelete = outcome else {
            Issue.record("expected .nothingToDelete, got \(outcome)")
            return
        }
        #expect(f.library.deleteCalls.isEmpty)
    }
}

@Suite("Persistence")
struct PersistenceTests {
    @Test func storeRoundTrip() throws {
        let store = Fixture.tempStore()
        #expect(store.load() == ProgressData())
        let data = ProgressData(reviewedIDs: ["a", "b"], pendingTrashIDs: ["c", "d"], bytesFreed: 1234)
        try store.save(data)
        #expect(store.load() == data)
    }

    @Test func corruptFileLoadsAsEmpty() throws {
        let store = Fixture.tempStore()
        try store.save(ProgressData(bytesFreed: 1))
        try Data("not json".utf8).write(to: store.fileURL)
        #expect(store.load() == ProgressData())
    }

    @Test func mutationsArePersisted() async {
        let f = await Fixture.make()
        f.session.keep()
        f.session.trash()
        await f.session.flush()
        let saved = f.store.load()
        #expect(saved.reviewedIDs == ["0"])
        #expect(saved.pendingTrashIDs == ["1"])
    }

    @Test func reloadFiltersReviewedAndKeepsPendingPile() async {
        let f = await Fixture.make()
        f.session.keep()
        f.session.trash()
        f.session.favorite()
        await f.session.flush()

        let reopened = SwipeSession(library: f.library, store: f.store)
        await reopened.load()
        #expect(reopened.queue.map(\.id) == ["3", "4"])
        #expect(reopened.pendingTrash.map(\.id) == ["1"])
        #expect(reopened.pendingTrashBytes == 100)
        #expect(reopened.reviewedIDs == ["0", "2"])
        #expect(!reopened.canUndo)
    }

    @Test func reloadDropsPendingItemsThatAreGone() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        await f.session.flush()
        f.library.items.removeAll { $0.id == "0" }

        let reopened = SwipeSession(library: f.library, store: f.store)
        await reopened.load()
        #expect(reopened.pendingTrash.map(\.id) == ["1"])
        await reopened.flush()
        #expect(f.store.load().pendingTrashIDs == ["1"])
    }

    @Test func resetProgressClearsReviewedKeepsPileAndLifetimeBytes() async {
        let f = await Fixture.make()
        f.session.keep()
        f.session.trash()
        f.session.trash()
        await f.session.commitTrash()
        f.session.trash()   // item "3"
        await f.session.resetProgress()
        #expect(f.session.reviewedIDs.isEmpty)
        #expect(f.session.pendingTrash.map(\.id) == ["3"])
        #expect(f.session.bytesFreed == 200)
        // "0" returns to the queue; the pending "3" does not.
        #expect(f.session.queue.map(\.id) == ["0", "4"])
        await f.session.flush()
        let saved = f.store.load()
        #expect(saved.reviewedIDs.isEmpty)
        #expect(saved.pendingTrashIDs == ["3"])
        #expect(saved.bytesFreed == 200)
    }

    @Test func accessDeniedLeavesQueueEmpty() async {
        let library = FakePhotoLibrary(items: [MediaItem(id: "0")])
        library.accessLevel = .denied
        let session = SwipeSession(library: library, store: Fixture.tempStore())
        await session.start()
        #expect(session.access == .denied)
        #expect(session.queue.isEmpty)
    }
}
