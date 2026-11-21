import AVFoundation
import UIKit
import Foundation
import Testing
@testable import PhotoCleaner

private struct Boom: Error {}

@Suite("SwipeSession favorite writes")
struct FavoriteWriteTests {
    @Test func undoWhileFavoriteWriteIsInFlightRunsWritesInOrderAndEndsUnfavorited() async {
        let f = await Fixture.make()
        let gate = Gate()
        f.library.beforeFavorite = { _, value in if value { await gate.wait() } }

        f.session.favorite()
        await gate.untilWaiting()
        f.session.undo()
        // The revert must queue behind the pending write instead of racing it.
        #expect(f.library.favoriteCalls.map(\.value) == [true])
        #expect(f.session.current?.id == "0")
        #expect(f.session.reviewedIDs.isEmpty)

        gate.open()
        await f.session.flush()
        #expect(f.library.favoriteCalls.map(\.value) == [true, false])
        #expect(!f.library.isFavorite("0"))
    }

    @Test func favoriteUndoFavoriteAgainEndsFavorited() async {
        let f = await Fixture.make()
        f.session.favorite()
        f.session.undo()
        f.session.favorite()
        await f.session.flush()
        #expect(f.library.favoriteCalls.map(\.value) == [true, false, true])
        #expect(f.library.isFavorite("0"))
        #expect(f.session.reviewedIDs == ["0"])
    }

    @Test func favoriteOfAlreadyFavoriteItemWritesNothingButMarksReviewed() async {
        let f = await Fixture.make(favorites: ["0"])
        f.session.favorite()
        await f.session.flush()
        #expect(f.library.favoriteCalls.isEmpty)
        #expect(f.session.reviewedIDs == ["0"])
        #expect(f.session.history.first?.wasFavorite == true)
    }

    @Test func failedFavoriteWriteIsSurfacedAndDoesNotBlockLaterWrites() async {
        let f = await Fixture.make()
        f.library.favoriteError = Boom()
        f.session.favorite()
        await f.session.flush()
        #expect(f.session.lastError is Boom)
        // The decision itself stands (the swipe is not reverted), and the queue keeps moving.
        #expect(f.session.reviewedIDs == ["0"])
        #expect(f.session.current?.id == "1")

        f.library.favoriteError = nil
        f.session.favorite()
        await f.session.flush()
        #expect(f.library.isFavorite("1"))
    }

    @Test func undoOfFavoriteAfterReloadStillRevertsFlag() async {
        let f = await Fixture.make()
        f.session.favorite()
        await f.session.flush()
        await f.session.load()
        #expect(f.session.canUndo)
        f.session.undo()
        await f.session.flush()
        #expect(!f.library.isFavorite("0"))
    }
}

@Suite("SwipeSession untrash")
struct UntrashTests {
    @Test func untrashedItemIsNotDeletedByCommit() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.session.trash()
        f.session.untrash("1")
        let outcome = await f.session.commitTrash()
        guard case .deleted(let count, let bytes) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 2)
        #expect(bytes == 200)
        #expect(f.library.deleteCalls == [["0", "2"]])
        #expect(f.library.items.map(\.id).contains("1"))
    }

    @Test func untrashUnknownIdIsNoOp() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.untrash("nope")
        f.session.untrash("3")   // in the queue, not in the pile
        #expect(f.session.pendingTrash.map(\.id) == ["0"])
        #expect(f.session.reviewedIDs.isEmpty)
        #expect(f.session.queue.map(\.id) == ["1", "2", "3", "4"])
    }

    @Test func untrashIsPersistedAsReviewed() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.session.untrash("0")
        await f.session.flush()
        let saved = f.store.load()
        #expect(saved.pendingTrashIDs == ["1"])
        #expect(saved.reviewedIDs == ["0"])
    }

    @Test func restoreToTrashIgnoresDuplicatesAndClampsIndex() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        let first = f.session.pendingTrash[0]
        // Already in the pile: nothing changes.
        f.session.restoreToTrash(first, at: 0)
        #expect(f.session.pendingTrash.map(\.id) == ["0", "1"])

        f.session.untrash("0")
        f.session.restoreToTrash(first, at: 99)
        #expect(f.session.pendingTrash.map(\.id) == ["1", "0"])
        f.session.untrash("1")
        f.session.restoreToTrash(f.session.queue[0], at: -5)
        #expect(f.session.pendingTrash.first?.id == "2")
    }

    @Test func untrashThenRestoreRoundTripsThroughPersistence() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        let item = f.session.pendingTrash[0]
        f.session.untrash(item.id)
        f.session.restoreToTrash(item, at: 0)
        await f.session.flush()
        let saved = f.store.load()
        #expect(saved.pendingTrashIDs == ["0", "1"])
        #expect(saved.reviewedIDs.isEmpty)
    }
}

@Suite("SwipeSession commit edge cases")
struct CommitEdgeCaseTests {
    @Test func cancelThenRetrySucceedsAndDeletesTheSameBatch() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.library.deleteError = PhotoLibraryError.userCancelled
        _ = await f.session.commitTrash()
        #expect(!f.session.isCommitting)
        #expect(f.session.lastError == nil)

        f.library.deleteError = nil
        let outcome = await f.session.commitTrash()
        guard case .deleted(let count, _) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 2)
        #expect(f.library.deleteCalls == [["0", "1"], ["0", "1"]])
        #expect(f.session.pendingTrash.isEmpty)
    }

    @Test func failureRecordsLastErrorAndLeavesPersistedPileIntact() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.library.deleteError = Boom()
        _ = await f.session.commitTrash()
        #expect(f.session.lastError is Boom)
        #expect(f.session.bytesFreed == 0)
        #expect(f.session.totalCount == 5)
        await f.session.flush()
        #expect(f.store.load().pendingTrashIDs == ["0", "1"])
        #expect(f.store.load().bytesFreed == 0)
    }

    @Test func cancelDoesNotSetLastError() async {
        let f = await Fixture.make()
        f.session.trash()
        f.library.deleteError = PhotoLibraryError.userCancelled
        _ = await f.session.commitTrash()
        #expect(f.session.lastError == nil)
    }

    @Test func secondCommitWhileOneIsInFlightIsRejected() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        let gate = Gate()
        f.library.beforeDelete = { _ in await gate.wait() }

        async let first = f.session.commitTrash()
        await gate.untilWaiting()
        #expect(f.session.isCommitting)
        async let second = f.session.commitTrash()
        for _ in 0..<20 { await Task.yield() }
        // The re-entrant call must bounce off before it reaches Photos.
        #expect(f.library.deleteCalls.count == 1)
        gate.open()

        let secondOutcome = await second
        guard case .nothingToDelete = secondOutcome else {
            Issue.record("expected .nothingToDelete for re-entrant commit, got \(secondOutcome)")
            return
        }
        let outcome = await first
        guard case .deleted(let count, _) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 2)
        #expect(f.library.deleteCalls.count == 1)
        #expect(!f.session.isCommitting)
    }

    @Test func itemTrashedWhileCommitIsInFlightStaysInPile() async {
        let f = await Fixture.make()
        f.session.trash()   // "0"
        let gate = Gate()
        f.library.beforeDelete = { _ in await gate.wait() }

        async let commit = f.session.commitTrash()
        await gate.untilWaiting()
        f.session.trash()   // "1", not part of the batch
        gate.open()
        _ = await commit

        #expect(f.library.deleteCalls == [["0"]])
        #expect(f.session.pendingTrash.map(\.id) == ["1"])
        #expect(f.session.bytesFreed == 100)
        await f.session.flush()
        #expect(f.store.load().pendingTrashIDs == ["1"])
    }

    @Test func undoDuringCommitDoesNotLeaveADeletedItemInTheQueue() async {
        // DEFECT (low severity, not reachable through the UI because the trash sheet is modal):
        // undo() is not guarded by isCommitting. If it pops a trash decision that is part of the
        // batch being deleted, the item re-enters the queue and is then deleted from Photos anyway.
        let f = await Fixture.make()
        f.session.trash()   // "0"
        let gate = Gate()
        f.library.beforeDelete = { _ in await gate.wait() }

        async let commit = f.session.commitTrash()
        await gate.untilWaiting()
        f.session.undo()
        gate.open()
        _ = await commit

        let deleted = Set(f.library.deleteCalls.flatMap { $0 })
        let queued = Set(f.session.queue.map(\.id))
        withKnownIssue("undo() during an in-flight commit resurrects an item that Photos then deletes") {
            #expect(deleted.isDisjoint(with: queued))
        }
    }

    @Test func undoAfterCommitDoesNotResurrectDeletedItems() async {
        let f = await Fixture.make()
        f.session.keep()    // "0"
        f.session.trash()   // "1"
        _ = await f.session.commitTrash()
        // The trash decision is gone from history; undo reverts the earlier keep.
        #expect(f.session.history.map(\.action) == [.keep])
        f.session.undo()
        #expect(f.session.current?.id == "0")
        #expect(!f.session.queue.map(\.id).contains("1"))
        #expect(!f.session.canUndo)
    }

    @Test func unknownSizesMeanZeroBytesAndNoSizeDisplay() async {
        let items = (0..<3).map { MediaItem(id: "\($0)") }
        let library = FakePhotoLibrary(items: items)   // no sizes registered
        let session = SwipeSession(library: library, store: Fixture.tempStore())
        await session.load()
        session.trash()
        session.trash()
        #expect(!session.pendingTrashHasSizes)
        #expect(session.pendingTrashBytes == 0)
        let outcome = await session.commitTrash()
        guard case .deleted(let count, let bytes) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 2)
        #expect(bytes == 0)
        #expect(session.bytesFreed == 0)
    }

    @Test func partiallyKnownSizesSumOnlyKnownOnes() async {
        let items = (0..<2).map { MediaItem(id: "\($0)") }
        let library = FakePhotoLibrary(items: items)
        library.sizes["1"] = 70
        let session = SwipeSession(library: library, store: Fixture.tempStore())
        await session.load()
        session.trash()
        session.trash()
        #expect(session.pendingTrashHasSizes)
        #expect(session.pendingTrashBytes == 70)
    }

    @Test func trashingEverythingEmptiesTheQueueAndCommitReportsAllOfIt() async {
        // The path that ends in the celebration screen with queueIsEmpty == true.
        let f = await Fixture.make(count: 3)
        f.session.trash()
        f.session.trash()
        f.session.trash()
        #expect(f.session.current == nil)
        #expect(f.session.reviewedCount == 0)
        let outcome = await f.session.commitTrash()
        guard case .deleted(let count, let bytes) = outcome else {
            Issue.record("expected .deleted, got \(outcome)")
            return
        }
        #expect(count == 3)
        #expect(bytes == 300)
        #expect(f.session.current == nil)
        #expect(f.session.pendingTrash.isEmpty)
        #expect(f.session.totalCount == 0)
        #expect(f.session.bytesFreed == 300)
        #expect(f.session.hasLoaded)
    }

    @Test func bytesFreedAccumulatesAcrossCommitsAndPersists() async {
        let f = await Fixture.make()
        f.session.trash()
        _ = await f.session.commitTrash()
        f.session.trash()
        f.session.trash()
        _ = await f.session.commitTrash()
        #expect(f.session.bytesFreed == 300)
        #expect(f.session.totalCount == 2)
        await f.session.flush()
        #expect(f.store.load().bytesFreed == 300)
    }
}

@Suite("SwipeSession library changes and empty library")
struct LibraryChangeTests {
    @Test func emptyLibraryLoadsWithoutCurrentAndEveryActionIsANoOp() async {
        let f = await Fixture.make(count: 0)
        #expect(f.session.hasLoaded)
        #expect(f.session.current == nil)
        #expect(f.session.totalCount == 0)
        #expect(f.session.remainingCount == 0)
        f.session.keep()
        f.session.trash()
        f.session.favorite()
        f.session.undo()
        #expect(f.session.history.isEmpty)
        #expect(f.session.reviewedIDs.isEmpty)
        #expect(f.session.pendingTrash.isEmpty)
        #expect(f.session.reviewedCount == 0)
        let outcome = await f.session.commitTrash()
        guard case .nothingToDelete = outcome else {
            Issue.record("expected .nothingToDelete, got \(outcome)")
            return
        }
        #expect(f.library.favoriteCalls.isEmpty)
        #expect(f.library.deleteCalls.isEmpty)
    }

    @Test func queueItemDeletedExternallyDisappearsOnReload() async {
        let f = await Fixture.make()
        f.library.items.removeAll { $0.id == "0" || $0.id == "3" }
        await f.session.load()
        #expect(f.session.queue.map(\.id) == ["1", "2", "4"])
        #expect(f.session.current?.id == "1")
        #expect(f.session.totalCount == 3)
    }

    @Test func decidedItemDeletedExternallyIsDroppedFromUndoHistory() async {
        let f = await Fixture.make()
        f.session.keep()    // "0"
        f.session.keep()    // "1"
        f.library.items.removeAll { $0.id == "1" }
        await f.session.load()
        // Undo must not resurrect "1"; it reverts the earlier "0".
        #expect(f.session.history.map(\.item.id) == ["0"])
        f.session.undo()
        #expect(f.session.current?.id == "0")
        #expect(!f.session.queue.map(\.id).contains("1"))
    }

    @Test func pendingItemDeletedExternallyLeavesPileAndPersistsWithoutIt() async {
        let f = await Fixture.make()
        f.session.trash()
        f.session.trash()
        f.library.items.removeAll { $0.id == "0" }
        await f.session.load()
        #expect(f.session.pendingTrash.map(\.id) == ["1"])
        #expect(f.session.pendingTrashBytes == 100)
        await f.session.flush()
        #expect(f.store.load().pendingTrashIDs == ["1"])
    }

    @Test func commitAfterExternalDeletionOfWholePileStillClearsIt() async {
        let f = await Fixture.make()
        f.session.trash()
        f.library.items.removeAll { $0.id == "0" }
        await f.session.load()
        #expect(f.session.pendingTrash.isEmpty)
        let outcome = await f.session.commitTrash()
        guard case .nothingToDelete = outcome else {
            Issue.record("expected .nothingToDelete, got \(outcome)")
            return
        }
    }

    @Test func newlyAddedPhotosAppearAtTheFrontOnReload() async {
        let f = await Fixture.make(count: 3)
        f.session.keep()
        f.library.items.insert(MediaItem(id: "new"), at: 0)
        await f.session.load()
        #expect(f.session.queue.map(\.id) == ["new", "1", "2"])
        #expect(f.session.totalCount == 4)
        // Undo still works for the earlier decision and puts it in front.
        f.session.undo()
        #expect(f.session.queue.map(\.id) == ["0", "new", "1", "2"])
    }

    @Test func libraryEmptiedExternallyShowsEmptyState() async {
        let f = await Fixture.make(count: 3)
        f.session.trash()
        f.library.items = []
        await f.session.load()
        #expect(f.session.current == nil)
        #expect(f.session.pendingTrash.isEmpty)
        #expect(f.session.totalCount == 0)
        #expect(f.session.history.isEmpty)
    }

    @Test func limitedAccessWithNoSelectedItemsIsEmptyButLoaded() async {
        let library = FakePhotoLibrary(items: [])
        library.accessLevel = .limited
        let session = SwipeSession(library: library, store: Fixture.tempStore())
        await session.start()
        #expect(session.access == .limited)
        #expect(session.hasLoaded)
        #expect(session.current == nil)
    }

    @Test func startRequestsAuthorizationOnlyWhenNotDetermined() async {
        final class Asking: PhotoLibraryProviding {
            let inner = FakePhotoLibrary(items: [MediaItem(id: "0")])
            var accessLevel: LibraryAccess = .notDetermined
            private(set) var requests = 0
            func requestAuthorization() async -> LibraryAccess { requests += 1; accessLevel = .authorized; return .authorized }
            func fetchItems() async -> [MediaItem] { await inner.fetchItems() }
            func image(for id: String, targetSize: CGSize) async -> UIImage? { nil }
            func playerItem(for id: String) async -> AVPlayerItem? { nil }
            func startCaching(ids: [String], targetSize: CGSize) {}
            func stopCaching() {}
            func setFavorite(_ isFavorite: Bool, forID id: String) async throws {}
            func delete(ids: [String]) async throws {}
            func byteSize(for id: String) -> Int64? { nil }
        }
        let library = Asking()
        let session = SwipeSession(library: library, store: Fixture.tempStore())
        #expect(!session.access.canRead)
        await session.start()
        #expect(library.requests == 1)
        #expect(session.access == .authorized)
        #expect(session.current?.id == "0")
        await session.start()
        #expect(library.requests == 1)
    }

    @Test func accessRevokedOnReloadEmptiesQueueButKeepsPileIDsOnDisk() async {
        let f = await Fixture.make()
        f.session.trash()
        await f.session.flush()
        f.library.accessLevel = .denied
        await f.session.load()
        #expect(f.session.queue.isEmpty)
        #expect(f.session.access == .denied)
        // Nothing was written that would forget the pile.
        #expect(f.store.load().pendingTrashIDs == ["0"])
    }

    @Test func concurrentLoadsAreCoalesced() async {
        let f = await Fixture.make()
        f.session.keep()
        async let a: Void = f.session.load()
        async let b: Void = f.session.load()
        _ = await (a, b)
        #expect(f.session.queue.map(\.id) == ["1", "2", "3", "4"])
        #expect(f.session.canUndo)
    }
}
