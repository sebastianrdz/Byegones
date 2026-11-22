import CoreGraphics
import Foundation
import Observation
import os

/// Something the person should be told about that did not come from a button they pressed.
nonisolated struct SessionNotice: Equatable, Sendable {
    enum Kind: Sendable { case favoriteFailed, unfavoriteFailed }
    var kind: Kind
    /// Changes on every notice, so the same kind twice in a row still reads as new.
    var serial: Int
}

@Observable
final class SwipeSession {
    /// How many items after the current one are kept warm in the image cache.
    static let prefetchDepth = 3

    private static let log = Logger(subsystem: "com.example.photocleaner", category: "session")

    // MARK: Observable state

    private(set) var access: LibraryAccess
    /// Unreviewed items, newest first. `queue.first` is `current`.
    private(set) var queue: [MediaItem] = []
    /// Oldest first; `undo()` pops the last.
    private(set) var history: [Decision] = []
    /// The pile as shown: oldest first, only items Photos returned. Persisted pile IDs that did
    /// not resolve in the latest fetch are kept on disk (see `unresolvedPendingIDs`), not shown.
    private(set) var pendingTrash: [MediaItem] = []
    private(set) var reviewedIDs: Set<String>
    private(set) var bytesFreed: Int64
    /// Size of the library at last `load()` (for "n of total" counters).
    private(set) var totalCount = 0
    private(set) var isLoading = false
    /// `true` once a load has completed with read access (distinguishes "loading" from "empty").
    private(set) var hasLoaded = false
    private(set) var isCommitting = false
    /// Last Photos failure from a fire-and-forget operation (favorite) or a failed delete.
    private(set) var lastError: (any Error)?
    /// A favorite write that failed. The view shows it as a toast.
    private(set) var notice: SessionNotice?

    var current: MediaItem? { queue.first }
    var remainingCount: Int { queue.count }
    var canUndo: Bool { !history.isEmpty && !isCommitting }
    var pendingTrashBytes: Int64 { pendingTrash.reduce(0) { $0 + ($1.byteSize ?? 0) } }
    /// `false` when no item in the pile has a known size (the size API is unavailable).
    var pendingTrashHasSizes: Bool { pendingTrash.contains { $0.byteSize != nil } }
    /// Items reviewed in this library snapshot, for "n of total" style displays.
    var reviewedCount: Int { max(0, totalCount - queue.count - pendingTrash.count) }

    /// Pixel size used for prefetching; the UI should set it to its card size.
    @ObservationIgnored var prefetchTargetSize = CGSize(width: 1200, height: 1600)

    // MARK: Collaborators

    /// Exposed so views can load images and players for items.
    let library: any PhotoLibraryProviding
    @ObservationIgnored private let store: ProgressStore

    /// Persisted pile IDs that the latest fetch did not return. They stay on disk until Photos
    /// confirms they are gone (full access only); a short fetch must never shrink the pile.
    @ObservationIgnored private var unresolvedPendingIDs: [String]
    @ObservationIgnored private var sizeCache: [String: Int64] = [:]
    /// Items whose size lookup came back empty. Cached so the lookup never repeats at drag frequency.
    @ObservationIgnored private var unknownSizeIDs: Set<String> = []
    /// The answer to our own authorization request. `authorizationStatus` can briefly keep saying
    /// "not determined" after the system prompt was answered; until it catches up, the answer wins.
    @ObservationIgnored private var requestedAccess: LibraryAccess?
    @ObservationIgnored private var loadedRevision = -1
    @ObservationIgnored private var reloadRequested = false
    @ObservationIgnored private var noticeSerial = 0

    // Photos favorite writes run in order, off the gesture path.
    @ObservationIgnored private var libraryWork: Task<Void, Never>?
    // Writes are coalesced: a burst of swipes produces at most one write in flight plus one queued.
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var dirtySnapshot: ProgressData?

    init(library: any PhotoLibraryProviding, store: ProgressStore = ProgressStore()) {
        self.library = library
        self.store = store
        let saved = store.load()
        reviewedIDs = saved.reviewedIDs
        unresolvedPendingIDs = saved.pendingTrashIDs
        bytesFreed = saved.bytesFreed
        access = library.accessLevel
    }

    // MARK: Loading

    /// Requests access if it was never asked, then loads.
    func start() async {
        access = resolvedAccess()
        if access == .notDetermined {
            let answer = await library.requestAuthorization()
            requestedAccess = answer
            access = answer
        }
        await load()
    }

    private func resolvedAccess() -> LibraryAccess {
        let reported = library.accessLevel
        if reported != .notDetermined { requestedAccess = nil }
        if reported == .notDetermined, let requestedAccess { return requestedAccess }
        return reported
    }

    /// Reloads only if something could have changed: never loaded, access changed, or Photos
    /// reported a library change since the last fetch. Use this on foreground.
    func reloadIfNeeded() async {
        if !hasLoaded || resolvedAccess() != access || library.changeRevision != loadedRevision {
            await load()
        }
    }

    /// Fetches the library and rebuilds the queue and the trash pile.
    ///
    /// A call made while a load is running does not start a second one: it records that another
    /// pass is wanted, and the running load performs exactly one more pass when it finishes, so
    /// picker, foreground and reset triggers are never lost.
    func load() async {
        guard !isLoading else {
            reloadRequested = true
            return
        }
        isLoading = true
        defer { isLoading = false }
        repeat {
            reloadRequested = false
            await performLoad()
        } while reloadRequested
    }

    private func performLoad() async {
        access = resolvedAccess()
        guard access.canRead else {
            queue = []
            return
        }

        // Read before fetching: a change that lands mid-fetch leaves `loadedRevision` behind, so the
        // next `reloadIfNeeded()` fetches again.
        let revision = library.changeRevision
        let items = await library.fetchItems()
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Pile IDs that did not come back are not dropped just for that: only Photos confirming
        // (full access) that they no longer exist removes them.
        let unresolvedNow = pendingCandidates().filter { byID[$0] == nil }
        var missing = Set<String>()
        if access == .authorized, !unresolvedNow.isEmpty {
            missing = await library.missingIDs(among: unresolvedNow)
        }

        // Sizes for pile items that are not cached yet, read off the main actor in one batch.
        let needSizes = pendingCandidates().filter { byID[$0] != nil && sizeCache[$0] == nil && !unknownSizeIDs.contains($0) }
        if !needSizes.isEmpty {
            let sizes = await library.byteSizes(for: needSizes)
            for id in needSizes {
                if let size = sizes[id] { sizeCache[id] = size } else { unknownSizeIDs.insert(id) }
            }
        }

        // From here on everything is synchronous, so state read now is state written now.
        let candidates = pendingCandidates()
        var resolved: [MediaItem] = []
        var unresolved: [String] = []
        for id in candidates {
            if var item = byID[id] {
                item.byteSize = sizeCache[id]
                resolved.append(item)
            } else if !missing.contains(id) {
                unresolved.append(id)
            }
        }
        let pruned = candidates.count - resolved.count - unresolved.count
        totalCount = items.count
        pendingTrash = resolved
        unresolvedPendingIDs = unresolved

        let pendingSet = Set(candidates)
        let newQueue = items.filter { !reviewedIDs.contains($0.id) && !pendingSet.contains($0.id) }
        // Avoid churn (and a visible reshuffle) when a foreground reload finds nothing new.
        if newQueue.map(\.id) != queue.map(\.id) { queue = newQueue }
        // Undo survives a reload as long as the decided item still exists.
        history.removeAll { byID[$0.item.id] == nil }
        hasLoaded = true
        loadedRevision = revision

        if pruned > 0 { persist() }
        refreshPrefetch()
    }

    /// Every pile ID in order: shown items first, then the ones awaiting confirmation.
    private func pendingCandidates() -> [String] {
        var seen = Set<String>()
        return (pendingTrash.map(\.id) + unresolvedPendingIDs).filter { seen.insert($0).inserted }
    }

    // MARK: Decisions

    func keep() { decide(.keep) }
    func trash() { decide(.trash) }
    func favorite() { decide(.favorite) }

    private func decide(_ action: DecisionAction) {
        guard let item = queue.first else { return }
        history.append(Decision(item: item, action: action, wasFavorite: item.isFavorite))
        queue.removeFirst()

        switch action {
        case .keep:
            reviewedIDs.insert(item.id)
        case .favorite:
            reviewedIDs.insert(item.id)
            if !item.isFavorite { setFavoriteInPhotos(true, id: item.id) }
        case .trash:
            var pending = item
            pending.byteSize = byteSize(of: item)
            pendingTrash.append(pending)
        }
        didMutate()
    }

    /// Reverts the last decision, including the favorite flag in Photos, and makes that item current.
    /// Ignored while a delete is in flight: the item could be one that Photos is deleting.
    func undo() {
        guard !isCommitting, let decision = history.popLast() else { return }
        let item = decision.item
        reviewedIDs.remove(item.id)
        pendingTrash.removeAll { $0.id == item.id }
        if decision.action == .favorite && !decision.wasFavorite {
            setFavoriteInPhotos(false, id: item.id)
        }
        queue.insert(item, at: 0)
        didMutate()
    }

    /// Takes an item out of the pile and treats it as kept.
    func untrash(_ id: String) {
        guard !isCommitting, pendingTrash.contains(where: { $0.id == id }) else { return }
        pendingTrash.removeAll { $0.id == id }
        reviewedIDs.insert(id)
        didMutate()
    }

    /// Puts an item that was just taken out of the pile back at `index` (undo of `untrash`).
    func restoreToTrash(_ item: MediaItem, at index: Int) {
        guard !isCommitting, !pendingTrash.contains(where: { $0.id == item.id }) else { return }
        reviewedIDs.remove(item.id)
        pendingTrash.insert(item, at: min(max(0, index), pendingTrash.count))
        didMutate()
    }

    /// Deletes the whole pile in one Photos change (one system confirmation).
    /// The pile and `bytesFreed` change only on success, and only items Photos actually deleted
    /// are counted.
    @discardableResult
    func commitTrash() async -> CommitOutcome {
        guard !isCommitting, !pendingTrash.isEmpty else { return .nothingToDelete }
        isCommitting = true
        defer { isCommitting = false }

        let batch = pendingTrash
        let batchIDs = Set(batch.map(\.id))
        let deletedIDs: [String]
        do {
            deletedIDs = try await library.delete(ids: batch.map(\.id))
        } catch PhotoLibraryError.userCancelled {
            return .cancelled
        } catch {
            lastError = error
            return .failed(error)
        }

        // Items that were already gone leave the pile too, but are not counted as cleared.
        let deleted = Set(deletedIDs).intersection(batchIDs)
        let bytes = batch.filter { deleted.contains($0.id) }.reduce(Int64(0)) { $0 + ($1.byteSize ?? 0) }
        pendingTrash.removeAll { batchIDs.contains($0.id) }
        // Deleted items can no longer be restored by undo.
        history.removeAll { batchIDs.contains($0.item.id) }
        totalCount = max(0, totalCount - deleted.count)
        bytesFreed += bytes
        didMutate()
        guard !deleted.isEmpty else { return .nothingToDelete }
        return .deleted(count: deleted.count, bytes: bytes)
    }

    /// Clears the review history so reviewed items return to the queue. The pending pile and
    /// the lifetime `bytesFreed` are kept.
    func resetProgress() async {
        reviewedIDs = []
        history = []
        persist()
        await load()
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: Sizes

    /// Cached size lookup for any item (for the current card's badge). Unknown sizes are cached
    /// too, so `PHAssetResource` is consulted at most once per item.
    func byteSize(of item: MediaItem) -> Int64? {
        if let known = item.byteSize { return known }
        if let cached = sizeCache[item.id] { return cached }
        if unknownSizeIDs.contains(item.id) { return nil }
        guard let size = library.byteSize(for: item.id) else {
            unknownSizeIDs.insert(item.id)
            return nil
        }
        sizeCache[item.id] = size
        return size
    }

    // MARK: Plumbing

    /// Waits for queued Photos writes and progress saves. Used by tests and when backgrounding.
    func flush() async {
        await libraryWork?.value
        await saveTask?.value
    }

    private func didMutate() {
        persist()
        refreshPrefetch()
    }

    private func refreshPrefetch() {
        let ids = queue.prefix(Self.prefetchDepth + 1).map(\.id)
        library.startCaching(ids: ids, targetSize: prefetchTargetSize)
    }

    private func setFavoriteInPhotos(_ value: Bool, id: String) {
        let previous = libraryWork
        let library = library
        libraryWork = Task {
            await previous?.value
            do {
                try await library.setFavorite(value, forID: id)
            } catch {
                favoriteWriteFailed(wanted: value, id: id, error: error)
            }
        }
    }

    private func favoriteWriteFailed(wanted: Bool, id: String, error: any Error) {
        lastError = error
        Self.log.error("Favorite write failed: \(error.localizedDescription, privacy: .public)")
        if wanted {
            // The star never landed, so this decision is now a plain keep. Undoing it must not
            // queue a write that tries to remove a favorite that was never added.
            if let index = history.lastIndex(where: { $0.item.id == id && $0.action == .favorite }) {
                let old = history[index]
                history[index] = Decision(item: old.item, action: .keep, wasFavorite: old.wasFavorite)
            }
        }
        noticeSerial += 1
        notice = SessionNotice(kind: wanted ? .favoriteFailed : .unfavoriteFailed, serial: noticeSerial)
    }

    private func persist() {
        dirtySnapshot = ProgressData(
            reviewedIDs: reviewedIDs,
            pendingTrashIDs: pendingTrash.map(\.id) + unresolvedPendingIDs,
            bytesFreed: bytesFreed
        )
        guard saveTask == nil else { return }
        saveTask = Task {
            while let snapshot = dirtySnapshot {
                dirtySnapshot = nil
                do {
                    try await store.saveInBackground(snapshot)
                } catch {
                    // Not fatal: the next mutation writes the full state again.
                    Self.log.error("Saving progress failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            saveTask = nil
        }
    }
}
