import Foundation

nonisolated enum MediaKind: String, Codable, Sendable {
    case photo
    case video
}

/// Plain value the session works on. Carries no `PHAsset`, so tests never need Photos.
nonisolated struct MediaItem: Identifiable, Hashable, Sendable {
    /// `PHAsset.localIdentifier`.
    let id: String
    var kind: MediaKind
    var creationDate: Date?
    /// Seconds; 0 for photos.
    var duration: TimeInterval
    var isFavorite: Bool
    /// Filled lazily; `nil` when unknown or unavailable.
    var byteSize: Int64?

    init(
        id: String,
        kind: MediaKind = .photo,
        creationDate: Date? = nil,
        duration: TimeInterval = 0,
        isFavorite: Bool = false,
        byteSize: Int64? = nil
    ) {
        self.id = id
        self.kind = kind
        self.creationDate = creationDate
        self.duration = duration
        self.isFavorite = isFavorite
        self.byteSize = byteSize
    }
}
