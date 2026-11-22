import AVFoundation
import UIKit
@testable import PhotoCleaner

final class FakePhotoLibrary: PhotoLibraryProviding {
    var accessLevel: LibraryAccess = .authorized
    var items: [MediaItem]
    var sizes: [String: Int64] = [:]
    /// When set, `delete` throws it.
    var deleteError: (any Error)?
    /// When set, `setFavorite` throws it (after recording the call).
    var favoriteError: (any Error)?
    /// Suspension points that let a test hold a Photos write in flight.
    var beforeFavorite: (@MainActor (_ id: String, _ value: Bool) async -> Void)?
    var beforeDelete: (@MainActor (_ ids: [String]) async -> Void)?
    private(set) var deleteCalls: [[String]] = []
    private(set) var favoriteCalls: [(id: String, value: Bool)] = []
    private(set) var cachedIDs: [String] = []
    /// Bumped by tests to mimic Photos reporting a library change.
    var changeRevision = 0
    /// Items that exist but are left out of `fetchItems()` (a short or limited fetch).
    var hiddenFromFetch: Set<String> = []
    private(set) var fetchCount = 0
    private(set) var byteSizeCalls = 0

    init(items: [MediaItem]) {
        self.items = items
    }

    func isFavorite(_ id: String) -> Bool {
        items.first { $0.id == id }?.isFavorite ?? false
    }

    func requestAuthorization() async -> LibraryAccess { accessLevel }
    func fetchItems() async -> [MediaItem] {
        fetchCount += 1
        return items.filter { !hiddenFromFetch.contains($0.id) }
    }
    func image(for id: String, targetSize: CGSize) async -> UIImage? { nil }
    func playerItem(for id: String) async -> AVPlayerItem? { nil }
    func startCaching(ids: [String], targetSize: CGSize) { cachedIDs = ids }
    func stopCaching() { cachedIDs = [] }
    func byteSize(for id: String) -> Int64? {
        byteSizeCalls += 1
        return sizes[id]
    }

    func missingIDs(among ids: [String]) async -> Set<String> {
        guard accessLevel == .authorized else { return [] }
        let existing = Set(items.map(\.id))
        return Set(ids.filter { !existing.contains($0) })
    }

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {
        favoriteCalls.append((id, isFavorite))
        await beforeFavorite?(id, isFavorite)
        if let favoriteError { throw favoriteError }
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isFavorite = isFavorite
        }
    }

    func delete(ids: [String]) async throws -> [String] {
        deleteCalls.append(ids)
        await beforeDelete?(ids)
        if let deleteError { throw deleteError }
        let existing = Set(items.map(\.id))
        let deleted = ids.filter { existing.contains($0) }
        items.removeAll { deleted.contains($0.id) }
        return deleted
    }
}

/// Suspension point: `wait()` suspends until `open()`. Any number of waiters. Main-actor only.
final class Gate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private(set) var isOpen = false
    private(set) var waiters = 0

    func wait() async {
        guard !isOpen else { return }
        waiters += 1
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        let pending = continuations
        continuations = []
        for continuation in pending { continuation.resume() }
    }

    /// Yields until a caller is suspended in `wait()`.
    func untilWaiting() async {
        while waiters == 0 { await Task.yield() }
    }
}
