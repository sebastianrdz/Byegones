import AVFoundation
import UIKit

nonisolated enum LibraryAccess: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case limited
    case authorized

    var canRead: Bool { self == .limited || self == .authorized }
}

nonisolated enum PhotoLibraryError: Error, Sendable, Equatable {
    /// The user dismissed the system delete confirmation.
    case userCancelled
    case assetNotFound
}

/// Everything the session needs from Photos. Main-actor isolated (module default).
protocol PhotoLibraryProviding: AnyObject {
    var accessLevel: LibraryAccess { get }
    func requestAuthorization() async -> LibraryAccess

    /// Images and videos from the user library, newest first.
    func fetchItems() async -> [MediaItem]

    /// Final-quality image; downloads from iCloud when needed. `nil` on failure.
    func image(for id: String, targetSize: CGSize) async -> UIImage?
    func playerItem(for id: String) async -> AVPlayerItem?

    /// Replaces the previous caching window with `ids`.
    func startCaching(ids: [String], targetSize: CGSize)
    func stopCaching()

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws
    /// One batched change, one system confirmation. Throws `PhotoLibraryError.userCancelled` on cancel.
    func delete(ids: [String]) async throws
    /// `nil` when unknown. Must never crash.
    func byteSize(for id: String) -> Int64?
}
