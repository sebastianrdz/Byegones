import AVFoundation
import UIKit

/// Reads from the real library but never writes to it. Used only in screenshot mode.
final class ScreenshotPhotoLibrary: PhotoLibraryProviding {
    private let base: any PhotoLibraryProviding

    init(base: any PhotoLibraryProviding) {
        self.base = base
    }

    var accessLevel: LibraryAccess { base.accessLevel }
    func requestAuthorization() async -> LibraryAccess { await base.requestAuthorization() }
    func fetchItems() async -> [MediaItem] { await base.fetchItems() }
    func image(for id: String, targetSize: CGSize) async -> UIImage? { await base.image(for: id, targetSize: targetSize) }
    func playerItem(for id: String) async -> AVPlayerItem? { await base.playerItem(for: id) }
    func startCaching(ids: [String], targetSize: CGSize) { base.startCaching(ids: ids, targetSize: targetSize) }
    func stopCaching() { base.stopCaching() }
    func byteSize(for id: String) -> Int64? { base.byteSize(for: id) }

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {}
    func delete(ids: [String]) async throws {}
}
