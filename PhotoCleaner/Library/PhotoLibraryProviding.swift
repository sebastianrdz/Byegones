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
    /// Increases whenever Photos reports a change to the library, by anyone (including this app).
    /// Safe to read from the main actor at any time.
    var changeRevision: Int { get }
    func requestAuthorization() async -> LibraryAccess

    /// Images and videos from the user library, newest first. Enumerated off the main actor.
    func fetchItems() async -> [MediaItem]

    /// Final-quality image; downloads from iCloud when needed. `nil` on failure.
    /// Cancelling the calling task cancels the underlying Photos request.
    func image(for id: String, targetSize: CGSize) async -> UIImage?
    /// A small image that is already on the device. Never starts an iCloud download.
    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage?
    func playerItem(for id: String) async -> AVPlayerItem?

    /// Replaces the previous caching window with `ids`.
    func startCaching(ids: [String], targetSize: CGSize)
    func stopCaching()

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws
    /// One batched change, one system confirmation. Throws `PhotoLibraryError.userCancelled` on cancel.
    /// Returns the identifiers that existed and were deleted; anything already gone is not counted.
    func delete(ids: [String]) async throws -> [String]

    /// `nil` when unknown. Must never crash.
    func byteSize(for id: String) -> Int64?
    /// Batch version for piles of items; reads off the main actor. Unknown sizes are omitted.
    func byteSizes(for ids: [String]) async -> [String: Int64]

    /// The subset of `ids` that Photos confirms no longer exist. Empty unless access is full,
    /// because under Limited access an item can be missing from a fetch while still being there.
    func missingIDs(among ids: [String]) async -> Set<String>
}

extension PhotoLibraryProviding {
    var changeRevision: Int { 0 }
    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? { nil }
    func byteSizes(for ids: [String]) async -> [String: Int64] {
        var result: [String: Int64] = [:]
        for id in ids { if let size = byteSize(for: id) { result[id] = size } }
        return result
    }
    func missingIDs(among ids: [String]) async -> Set<String> { [] }
}
