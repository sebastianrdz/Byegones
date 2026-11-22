import AVFoundation
import UIKit

/// Reads from the real library but never writes to it. Used only in screenshot mode.
final class ScreenshotPhotoLibrary: PhotoLibraryProviding {
    struct ForcedFailure: Error {}

    private let base: any PhotoLibraryProviding
    /// Screenshot scenes that show an error state make the write fail instead of no-op.
    private let failWrites: Bool

    init(base: any PhotoLibraryProviding, failWrites: Bool = false) {
        self.base = base
        self.failWrites = failWrites
    }

    var accessLevel: LibraryAccess { base.accessLevel }
    var changeRevision: Int { base.changeRevision }
    func requestAuthorization() async -> LibraryAccess { await base.requestAuthorization() }
    func fetchItems() async -> [MediaItem] { await base.fetchItems() }
    func image(for id: String, targetSize: CGSize) async -> UIImage? { await base.image(for: id, targetSize: targetSize) }
    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? { await base.thumbnail(for: id, targetSize: targetSize) }
    func playerItem(for id: String) async -> AVPlayerItem? { await base.playerItem(for: id) }
    func startCaching(ids: [String], targetSize: CGSize) { base.startCaching(ids: ids, targetSize: targetSize) }
    func stopCaching() { base.stopCaching() }
    func byteSize(for id: String) -> Int64? { base.byteSize(for: id) }
    func byteSizes(for ids: [String]) async -> [String: Int64] { await base.byteSizes(for: ids) }
    func missingIDs(among ids: [String]) async -> Set<String> { [] }

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {
        if failWrites { throw ForcedFailure() }
    }

    func delete(ids: [String]) async throws -> [String] {
        if failWrites { throw ForcedFailure() }
        return ids
    }
}
