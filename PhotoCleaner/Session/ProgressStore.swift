import Foundation

nonisolated struct ProgressData: Codable, Equatable, Sendable {
    var reviewedIDs: Set<String> = []
    /// Ordered, oldest first.
    var pendingTrashIDs: [String] = []
    /// Lifetime total.
    var bytesFreed: Int64 = 0
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

    /// Missing or unreadable file yields empty progress.
    func load() -> ProgressData {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(ProgressData.self, from: data)
        else { return ProgressData() }
        return decoded
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
