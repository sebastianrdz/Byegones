import Foundation

nonisolated struct ProgressData: Codable, Equatable, Sendable {
    var reviewedIDs: Set<String> = []
    /// Ordered, oldest first.
    var pendingTrashIDs: [String] = []
    /// Lifetime total.
    var bytesFreed: Int64 = 0

    init(reviewedIDs: Set<String> = [], pendingTrashIDs: [String] = [], bytesFreed: Int64 = 0) {
        self.reviewedIDs = reviewedIDs
        self.pendingTrashIDs = pendingTrashIDs
        self.bytesFreed = bytesFreed
    }

    private enum CodingKeys: String, CodingKey {
        case reviewedIDs, pendingTrashIDs, bytesFreed
    }

    /// Every field is optional on disk, so a file written by an older or newer build never
    /// wipes what it does contain.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reviewedIDs = try container.decodeIfPresent(Set<String>.self, forKey: .reviewedIDs) ?? []
        pendingTrashIDs = try container.decodeIfPresent([String].self, forKey: .pendingTrashIDs) ?? []
        bytesFreed = try container.decodeIfPresent(Int64.self, forKey: .bytesFreed) ?? 0
    }
}

/// JSON persistence in Application Support. Left in device backups on purpose (the privacy
/// policy discloses it), so `isExcludedFromBackup` is not set.
nonisolated struct ProgressStore: Sendable {
    let fileURL: URL

    init(fileURL: URL = Self.defaultFileURL) {
        self.fileURL = fileURL
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "progress.json", directoryHint: .notDirectory)
    }

    /// Where a file that could not be read is moved, so the next save cannot overwrite it.
    var corruptFileURL: URL {
        fileURL.deletingLastPathComponent().appending(path: "progress.corrupt.json", directoryHint: .notDirectory)
    }

    /// A missing file yields empty progress. A file that exists but cannot be read or decoded is
    /// moved aside to `progress.corrupt.json` (replacing an older one) before empty progress is
    /// returned, so a later save never silently destroys it.
    func load() -> ProgressData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return ProgressData() }
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ProgressData.self, from: data) {
            return decoded
        }
        quarantine()
        return ProgressData()
    }

    private func quarantine() {
        let manager = FileManager.default
        try? manager.removeItem(at: corruptFileURL)
        // If the move itself fails the file stays where it is; nothing is deleted.
        try? manager.moveItem(at: fileURL, to: corruptFileURL)
    }

    func save(_ progress: ProgressData) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(progress)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Same as `save`, but off the main actor. Large libraries mean a multi-megabyte file.
    @concurrent
    func saveInBackground(_ progress: ProgressData) async throws {
        try save(progress)
    }
}
