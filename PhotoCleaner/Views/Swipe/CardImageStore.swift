import Observation
import UIKit

/// Shared image cache for the front, next and departing cards, so a card keeps its picture while
/// it changes role. Backed by `PHCachingImageManager` through the library.
///
/// Every request is a `Task` that is cancelled when its card leaves the window, which cancels the
/// Photos request behind it. Fast swiping through iCloud-only items therefore never leaves a pile
/// of downloads running.
@Observable
final class CardImageStore {
    private(set) var images: [String: UIImage] = [:]
    /// Low-resolution, on-device stand-ins shown while the full image downloads.
    private(set) var thumbnails: [String: UIImage] = [:]
    private(set) var downloading: Set<String> = []
    private(set) var failed: Set<String> = []

    @ObservationIgnored var targetSize = CGSize(width: 1200, height: 1600)
    private struct Request {
        let token: UUID
        let task: Task<Void, Never>
    }

    @ObservationIgnored private var requests: [String: Request] = [:]
    /// Most recently wanted last. Bounds `images`, `thumbnails` and `failed` together.
    @ObservationIgnored private var order: [String] = []
    @ObservationIgnored private let capacity = 10
    @ObservationIgnored private let library: any PhotoLibraryProviding

    init(library: any PhotoLibraryProviding) {
        self.library = library
    }

    func ensure(_ item: MediaItem) {
        touch(item.id)
        guard images[item.id] == nil, requests[item.id] == nil else { return }
        failed.remove(item.id)
        let id = item.id
        let size = targetSize
        let library = library

        let token = UUID()
        let task = Task {
            // Only if the full image is slow (iCloud) do we look for a local thumbnail and show the
            // chip. The thumbnail request never touches the network, so it cannot add a download.
            let slow = Task {
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                downloading.insert(id)
                if let thumb = await library.thumbnail(for: id, targetSize: CGSize(width: 400, height: 533)),
                   images[id] == nil, !Task.isCancelled {
                    thumbnails[id] = thumb
                }
            }
            let full = await library.image(for: id, targetSize: size)
            slow.cancel()
            // Only clear our own registration: the card may have left and come back meanwhile.
            if requests[id]?.token == token {
                requests[id] = nil
                downloading.remove(id)
            }
            // A cancelled request is not a failure: the card simply left the window.
            guard !Task.isCancelled else { return }
            if let full {
                images[id] = full
                thumbnails[id] = nil
            } else {
                failed.insert(id)
            }
            evictIfNeeded()
        }
        requests[id] = Request(token: token, task: task)
    }

    func retry(_ item: MediaItem) {
        failed.remove(item.id)
        ensure(item)
    }

    /// Cancels requests for cards that are no longer in the window and drops their state.
    func prune(keeping ids: Set<String>) {
        for (id, request) in requests where !ids.contains(id) {
            request.task.cancel()
            requests[id] = nil
            downloading.remove(id)
        }
        for id in Array(failed) where !ids.contains(id) { failed.remove(id) }
        for id in Array(thumbnails.keys) where !ids.contains(id) { thumbnails[id] = nil }
    }

    private func touch(_ id: String) {
        order.removeAll { $0 == id }
        order.append(id)
    }

    /// Evicts the oldest entries that are not in flight. In-flight ones stay in `order`.
    private func evictIfNeeded() {
        while order.count > capacity {
            guard let index = order.firstIndex(where: { requests[$0] == nil }) else { return }
            let evicted = order.remove(at: index)
            images[evicted] = nil
            thumbnails[evicted] = nil
            failed.remove(evicted)
        }
    }
}
