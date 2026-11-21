import AVFoundation
import UIKit
@testable import PhotoCleaner

final class FakePhotoLibrary: PhotoLibraryProviding {
    var accessLevel: LibraryAccess = .authorized
    var items: [MediaItem]
    var sizes: [String: Int64] = [:]
    /// When set, `delete` throws it.
    var deleteError: (any Error)?
    private(set) var deleteCalls: [[String]] = []
    private(set) var favoriteCalls: [(id: String, value: Bool)] = []
    private(set) var cachedIDs: [String] = []

    init(items: [MediaItem]) {
        self.items = items
    }

    func isFavorite(_ id: String) -> Bool {
        items.first { $0.id == id }?.isFavorite ?? false
    }

    func requestAuthorization() async -> LibraryAccess { accessLevel }
    func fetchItems() async -> [MediaItem] { items }
    func image(for id: String, targetSize: CGSize) async -> UIImage? { nil }
    func playerItem(for id: String) async -> AVPlayerItem? { nil }
    func startCaching(ids: [String], targetSize: CGSize) { cachedIDs = ids }
    func stopCaching() { cachedIDs = [] }
    func byteSize(for id: String) -> Int64? { sizes[id] }

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {
        favoriteCalls.append((id, isFavorite))
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isFavorite = isFavorite
        }
    }

    func delete(ids: [String]) async throws {
        deleteCalls.append(ids)
        if let deleteError { throw deleteError }
        items.removeAll { ids.contains($0.id) }
    }
}
