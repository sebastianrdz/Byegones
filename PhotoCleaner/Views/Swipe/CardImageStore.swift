import Observation
import UIKit

/// Shared image cache for the front, next and departing cards, so a card keeps its picture while
/// it changes role. Backed by `PHCachingImageManager` through the library.
@Observable
final class CardImageStore {
    private(set) var images: [String: UIImage] = [:]
    /// Low-resolution stand-ins shown while the full image downloads.
    private(set) var thumbnails: [String: UIImage] = [:]
    private(set) var downloading: Set<String> = []
    private(set) var failed: Set<String> = []

    @ObservationIgnored var targetSize = CGSize(width: 1200, height: 1600)
    @ObservationIgnored private var inflight: Set<String> = []
    @ObservationIgnored private var order: [String] = []
    @ObservationIgnored private let capacity = 10
    @ObservationIgnored private let library: any PhotoLibraryProviding

    init(library: any PhotoLibraryProviding) {
        self.library = library
    }

    func ensure(_ item: MediaItem) {
        touch(item.id)
        guard images[item.id] == nil, !inflight.contains(item.id) else { return }
        inflight.insert(item.id)
        failed.remove(item.id)
        let id = item.id
        let size = targetSize
        let library = library

        Task {
            // Only if the full image is slow (iCloud) do we fetch a thumbnail and show the chip.
            let slow = Task {
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                downloading.insert(id)
                if let thumb = await library.image(for: id, targetSize: CGSize(width: 400, height: 533)),
                   images[id] == nil {
                    thumbnails[id] = thumb
                }
            }
            let full = await library.image(for: id, targetSize: size)
            slow.cancel()
            inflight.remove(id)
            downloading.remove(id)
            if let full {
                images[id] = full
                thumbnails[id] = nil
            } else {
                failed.insert(id)
            }
            evictIfNeeded()
        }
    }

    func retry(_ item: MediaItem) {
        failed.remove(item.id)
        ensure(item)
    }

    private func touch(_ id: String) {
        order.removeAll { $0 == id }
        order.append(id)
    }

    private func evictIfNeeded() {
        while order.count > capacity {
            let oldest = order.removeFirst()
            guard !inflight.contains(oldest) else { continue }
            images[oldest] = nil
            thumbnails[oldest] = nil
        }
    }
}
