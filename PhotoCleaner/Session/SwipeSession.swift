import CoreGraphics
import Foundation
import Observation

@Observable
final class SwipeSession {
    /// How many items after the current one are kept warm in the image cache.
    static let prefetchDepth = 3

    // MARK: Observable state

    private(set) var access: LibraryAccess
    /// Unreviewed items, newest first. `queue.first` is `current`.
    private(set) var queue: [MediaItem] = []
    /// Oldest first; `undo()` pops the last.
    private(set) var history: [Decision] = []
    /// Ordered, oldest first.
    private(set) var pendingTrash: [MediaItem] = []
    private(set) var reviewedIDs: Set<String>
    private(set) var bytesFreed: Int64
    /// Size of the library at last `load()` (for "n of total" counters).
    private(set) var totalCount = 0
    private(set) var isLoading = false
    /// `true` once a load has completed with read access (distinguishes "loading" from "empty").
    private(set) var hasLoaded = false
    private(set) var isCommitting = false
    /// Last Photos failure from a fire-and-forget operation (favorite).
    private(set) var lastError: (any Error)?

    var current: MediaItem? { queue.first }
    var remainingCount: Int { queue.count }
    var canUndo: Bool { !history.isEmpty }
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

    @ObservationIgnored private var unresolvedPendingIDs: [String]
    @ObservationIgnored private var sizeCache: [String: Int64] = [:]

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
        access = library.accessLevel
        if access == .notDetermined {
            access = await library.requestAuthorization()
        }
        await load()
    }

    /// Fetches the library and rebuilds the queue and the trash pile.
    /// Pending IDs that no longer exist are dropped.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        access = library.accessLevel
        guard access.canRead else {
            queue = []
            return
        }

        let items = await library.fetchItems()
        totalCount = items.count

        let pendingIDs = hasLoaded ? pendingTrash.map(\.id) : unresolvedPendingIDs
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let resolvedPending: [MediaItem] = pendingIDs.compactMap { id in
            guard var item = byID[id] else { return nil }
            item.byteSize = byteSize(of: item)
            return item
        }
        let pendingSet = Set(resolvedPending.map(\.id))

        pendingTrash = resolvedPending
        let newQueue = items.filter { !reviewedIDs.contains($0.id) && !pendingSet.contains($0.id) }
        // Avoid churn (and a visible reshuffle) when a foreground reload finds nothing new.
        if newQueue.map(\.id) != queue.map(\.id) { queue = newQueue }
        // Undo survives a reload as long as the decided item still exists.
        history.removeAll { byID[$0.item.id] == nil }
        hasLoaded = true
        unresolvedPendingIDs = []

        if resolvedPending.count != pendingIDs.count { persist() }
        refreshPrefetch()
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
    func undo() {
        guard let decision = history.popLast() else { return }
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
        guard pendingTrash.contains(where: { $0.id == id }) else { return }
        pendingTrash.removeAll { $0.id == id }
        reviewedIDs.insert(id)
        didMutate()
    }

    /// Puts an item that was just taken out of the pile back at `index` (undo of `untrash`).
    func restoreToTrash(_ item: MediaItem, at index: Int) {
        guard !pendingTrash.contains(where: { $0.id == item.id }) else { return }
        reviewedIDs.remove(item.id)
        pendingTrash.insert(item, at: min(max(0, index), pendingTrash.count))
        didMutate()
    }

    /// Deletes the whole pile in one Photos change (one system confirmation).
    /// The pile and `bytesFreed` change only on success.
    @discardableResult
    func commitTrash() async -> CommitOutcome {
        guard !isCommitting, !pendingTrash.isEmpty else { return .nothingToDelete }
        isCommitting = true
        defer { isCommitting = false }

        let batch = pendingTrash
        let ids = Set(batch.map(\.id))
        do {
            try await library.delete(ids: batch.map(\.id))
        } catch PhotoLibraryError.userCancelled {
            return .cancelled
        } catch {
            lastError = error
            return .failed(error)
        }

        let bytes = batch.reduce(Int64(0)) { $0 + ($1.byteSize ?? 0) }
        pendingTrash.removeAll { ids.contains($0.id) }
        // Deleted items can no longer be restored by undo.
        history.removeAll { ids.contains($0.item.id) }
        bytesFreed += bytes
        totalCount = max(0, totalCount - batch.count)
        didMutate()
        return .deleted(count: batch.count, bytes: bytes)
    }

    /// Clears the review history so reviewed items return to the queue. The pending pile and
    /// the lifetime `bytesFreed` are kept.
    func resetProgress() async {
        reviewedIDs = []
        history = []
        persist()
        await load()
    }

    // MARK: Sizes

    /// Cached size lookup for any item (for the current card's badge).
    func byteSize(of item: MediaItem) -> Int64? {
        if let known = item.byteSize { return known }
        if let cached = sizeCache[item.id] { return cached }
        guard let size = library.byteSize(for: item.id) else { return nil }
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
                lastError = error
            }
        }
    }

    private func persist() {
        dirtySnapshot = ProgressData(
            reviewedIDs: reviewedIDs,
            pendingTrashIDs: hasLoaded ? pendingTrash.map(\.id) : unresolvedPendingIDs,
            bytesFreed: bytesFreed
        )
        guard saveTask == nil else { return }
        saveTask = Task {
            while let snapshot = dirtySnapshot {
                dirtySnapshot = nil
                try? await store.saveInBackground(snapshot)
            }
            saveTask = nil
        }
    }
}
