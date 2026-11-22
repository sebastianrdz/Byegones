import Foundation
import os

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
    nonisolated enum StoreError: Error, Equatable {
        /// An unreadable file could not be moved aside, so saving would destroy it.
        case unreadableFileKept
    }

    /// How many quarantined copies are kept.
    static let quarantineLimit = 3

    private static let recognizedKeys: Set<String> = ["reviewedIDs", "pendingTrashIDs", "bytesFreed"]

    let fileURL: URL
    private let move: @Sendable (URL, URL) throws -> Void
    /// Set when an unreadable file could not be quarantined; `save` then refuses to write.
    private let blocked = OSAllocatedUnfairLock(initialState: false)

    init(
        fileURL: URL = Self.defaultFileURL,
        move: @escaping @Sendable (URL, URL) throws -> Void = { try FileManager.default.moveItem(at: $0, to: $1) }
    ) {
        self.fileURL = fileURL
        self.move = move
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "progress.json", directoryHint: .notDirectory)
    }

    private var directory: URL { fileURL.deletingLastPathComponent() }
    private static let quarantinePrefix = "progress.corrupt-"

    /// Quarantined copies, newest first (names carry an ISO 8601 timestamp, so they sort by time).
    var quarantinedFileURLs: [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasPrefix(Self.quarantinePrefix) && $0.hasSuffix(".json") }
            .sorted(by: >)
            .map { directory.appending(path: $0, directoryHint: .notDirectory) }
    }

    /// A missing file yields empty progress. A file that exists but cannot be read, is not a JSON
    /// object, or has none of the recognised keys is moved aside to a timestamped
    /// `progress.corrupt-<date>.json` (the last three are kept) before empty progress is returned.
    /// Individual missing keys are fine: they decode to defaults.
    func load() -> ProgressData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return ProgressData() }
        if let data = try? Data(contentsOf: fileURL),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           !Self.recognizedKeys.isDisjoint(with: object.keys),
           let decoded = try? JSONDecoder().decode(ProgressData.self, from: data) {
            return decoded
        }
        quarantine()
        return ProgressData()
    }

    /// Moves the unreadable file aside under a unique name. If that fails the file stays put and
    /// saving is refused, so the next save cannot silently overwrite what could not be read.
    private func quarantine() {
        // The name carries an ISO 8601 timestamp and a two-digit counter, so names sort by time even
        // for several quarantines in one second, without reading any file dates.
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        // One past the highest counter already used for this second. Counting free slots instead
        // would reuse a pruned name and make the newest copy sort as the oldest.
        let stampPrefix = "\(Self.quarantinePrefix)\(stamp)-"
        let used = quarantinedFileURLs.compactMap { url -> Int? in
            let name = url.lastPathComponent
            guard name.hasPrefix(stampPrefix) else { return nil }
            return Int(name.dropFirst(stampPrefix.count).prefix { $0.isNumber })
        }
        let counter = (used.max() ?? -1) + 1
        let destination = directory.appending(
            path: String(format: "\(stampPrefix)%02d.json", counter), directoryHint: .notDirectory
        )
        do {
            try move(fileURL, destination)
            blocked.withLock { $0 = false }
        } catch {
            blocked.withLock { $0 = true }
            return
        }
        for old in quarantinedFileURLs.dropFirst(Self.quarantineLimit) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    func save(_ progress: ProgressData) throws {
        if blocked.withLock({ $0 }) { throw StoreError.unreadableFileKept }
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
