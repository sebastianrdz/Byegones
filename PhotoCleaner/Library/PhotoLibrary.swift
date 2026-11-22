import AVFoundation
@preconcurrency import Photos
import UIKit
import os

// MARK: - Concurrency helpers
//
// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor makes every closure written in this file main-actor
// isolated unless it says otherwise. Photos calls most of its blocks on private queues, and a
// main-actor closure invoked there traps in _swift_task_checkIsolatedSwift. Every block handed to
// Photos below is therefore explicitly `@Sendable` (nonisolated) and touches only Sendable state.

/// Guards a continuation against Photos calling a result handler more than once.
private nonisolated final class ResumeOnce: Sendable {
    private let flag = OSAllocatedUnfairLock(initialState: false)
    /// `true` only for the first caller.
    func claim() -> Bool {
        flag.withLock { done in
            defer { done = true }
            return !done
        }
    }
}

/// Moves a non-Sendable Photos object across an isolation boundary. Each use is documented at the
/// call site: the value is only ever used by one party at a time, or the API is thread-safe.
private nonisolated struct Handoff<T>: @unchecked Sendable {
    let value: T
}

/// Lets a cancelled task cancel the Photos request it started. Safe against the cancel arriving
/// before the request ID is known.
private nonisolated final class RequestTicket: Sendable {
    private struct State { var id: PHImageRequestID?; var cancelled = false }
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let manager: Handoff<PHImageManager>

    init(manager: PHImageManager) {
        self.manager = Handoff(value: manager)
    }

    func set(_ id: PHImageRequestID) {
        let cancelNow = state.withLock { s -> Bool in
            s.id = id
            return s.cancelled
        }
        // PHImageManager.cancelImageRequest(_:) may be called from any thread.
        if cancelNow { manager.value.cancelImageRequest(id) }
    }

    func cancel() {
        let id = state.withLock { s -> PHImageRequestID? in
            s.cancelled = true
            return s.id
        }
        if let id { manager.value.cancelImageRequest(id) }
    }
}

/// Counts library changes reported by Photos. Photos calls `photoLibraryDidChange` on an arbitrary
/// queue, so this class is nonisolated and only touches a lock.
private nonisolated final class ChangeObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let count = OSAllocatedUnfairLock(initialState: 0)
    var revision: Int { count.withLock { $0 } }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        count.withLock { $0 += 1 }
    }
}

/// Small bounded cache of resolved assets. The library can hold tens of thousands; only the
/// handful near the current card are ever needed.
private struct AssetCache {
    private var storage: [String: PHAsset] = [:]
    private var order: [String] = []
    let capacity: Int

    init(capacity: Int) { self.capacity = capacity }

    subscript(id: String) -> PHAsset? {
        get { storage[id] }
        set {
            if let newValue {
                storage[id] = newValue
                order.removeAll { $0 == id }
                order.append(id)
                while order.count > capacity { storage[order.removeFirst()] = nil }
            } else {
                storage[id] = nil
                order.removeAll { $0 == id }
            }
        }
    }
}

// MARK: - PhotoLibrary

final class PhotoLibrary: PhotoLibraryProviding {
    private let cachingManager = PHCachingImageManager()
    private var assets = AssetCache(capacity: 64)
    private let observer = ChangeObserver()
    private var isObserving = false

    // The caching manager only serves cache hits when requests use the same options object,
    // target size and content mode as startCaching.
    private let imageOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        return options
    }()

    /// Local-only stand-in shown while the full image downloads. Never touches the network.
    private let thumbnailOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        return options
    }()

    private let videoOptions: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        return options
    }()

    deinit {
        if isObserving { PHPhotoLibrary.shared().unregisterChangeObserver(observer) }
    }

    // MARK: Authorization

    var accessLevel: LibraryAccess {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    var changeRevision: Int { observer.revision }

    func requestAuthorization() async -> LibraryAccess {
        Self.map(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    private static func map(_ status: PHAuthorizationStatus) -> LibraryAccess {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .limited: .limited
        case .authorized: .authorized
        @unknown default: .denied
        }
    }

    // MARK: Fetching

    func fetchItems() async -> [MediaItem] {
        // Registered once access exists, so merely creating the library never talks to Photos.
        if !isObserving {
            isObserving = true
            PHPhotoLibrary.shared().register(observer)
        }
        return await Self.enumerateLibrary()
    }

    /// Enumerates every image and video off the main actor and returns plain values. The
    /// `PHAsset`s never leave this function, so nothing large is retained.
    @concurrent
    private nonisolated static func enumerateLibrary() async -> [MediaItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue
        )
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let result = PHAsset.fetchAssets(with: options)
        var items: [MediaItem] = []
        items.reserveCapacity(result.count)
        for index in 0..<result.count {
            let asset = result.object(at: index)
            items.append(
                MediaItem(
                    id: asset.localIdentifier,
                    kind: asset.mediaType == .video ? .video : .photo,
                    creationDate: asset.creationDate,
                    duration: asset.mediaType == .video ? asset.duration : 0,
                    isFavorite: asset.isFavorite
                )
            )
        }
        return items
    }

    private func asset(for id: String) -> PHAsset? {
        if let cached = assets[id] { return cached }
        guard let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return nil
        }
        assets[id] = fetched
        return fetched
    }

    // MARK: Loading media

    func image(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = asset(for: id) else { return nil }
        let image = await requestImage(asset, targetSize: targetSize, options: imageOptions, waitsForFinal: true)
        // A failed request may mean the cached asset went stale (deleted elsewhere); resolve it
        // afresh next time so Retry can recover.
        if image == nil, !Task.isCancelled { assets[id] = nil }
        return image
    }

    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = asset(for: id) else { return nil }
        return await requestImage(asset, targetSize: targetSize, options: thumbnailOptions, waitsForFinal: false)
    }

    private func requestImage(
        _ asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions, waitsForFinal: Bool
    ) async -> UIImage? {
        let manager = cachingManager
        let once = ResumeOnce()
        let ticket = RequestTicket(manager: manager)
        let boxedAsset = Handoff(value: asset)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                // Explicitly @Sendable: Photos calls this on an arbitrary queue.
                let id = manager.requestImage(
                    for: boxedAsset.value, targetSize: targetSize, contentMode: .aspectFill, options: options
                ) { @Sendable image, info in
                    let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if waitsForFinal && degraded && image != nil { return }
                    if once.claim() { continuation.resume(returning: image) }
                }
                ticket.set(id)
            }
        } onCancel: {
            ticket.cancel()
        }
    }

    func playerItem(for id: String) async -> AVPlayerItem? {
        guard let asset = asset(for: id) else { return nil }
        let options = videoOptions
        let manager = cachingManager
        let once = ResumeOnce()
        let ticket = RequestTicket(manager: manager)
        let boxedAsset = Handoff(value: asset)
        let boxed: Handoff<AVPlayerItem?> = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Handoff<AVPlayerItem?>, Never>) in
                let id = manager.requestPlayerItem(forVideo: boxedAsset.value, options: options) {
                    @Sendable item, _ in
                    if once.claim() { continuation.resume(returning: Handoff(value: item)) }
                }
                ticket.set(id)
            }
        } onCancel: {
            ticket.cancel()
        }
        return boxed.value
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        cachingManager.stopCachingImagesForAllAssets()
        let resolved = ids.compactMap { asset(for: $0) }
        guard !resolved.isEmpty else { return }
        cachingManager.startCachingImages(for: resolved, targetSize: targetSize, contentMode: .aspectFill, options: imageOptions)
    }

    func stopCaching() {
        cachingManager.stopCachingImagesForAllAssets()
    }

    // MARK: Changes

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {
        // `@Sendable`: Photos runs the block on com.apple.PHPhotoLibrary.changes. Re-fetching
        // inside it means only a String crosses the boundary.
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return }
            PHAssetChangeRequest(for: asset).isFavorite = isFavorite
        }
    }

    func delete(ids: [String]) async throws -> [String] {
        guard !ids.isEmpty else { return [] }
        let existing = OSAllocatedUnfairLock<[String]>(initialState: [])
        do {
            // `@Sendable` for the same reason as `setFavorite`. The assets are resolved inside the
            // block, so what is reported as deleted is exactly what was handed to Photos.
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                var found: [String] = []
                found.reserveCapacity(fetched.count)
                for index in 0..<fetched.count { found.append(fetched.object(at: index).localIdentifier) }
                let snapshot = found
                existing.withLock { $0 = snapshot }
                if fetched.count > 0 { PHAssetChangeRequest.deleteAssets(fetched) }
            }
        } catch {
            // PHPhotosError.userCancelled == 3072.
            if (error as NSError).code == PHPhotosError.userCancelled.rawValue {
                throw PhotoLibraryError.userCancelled
            }
            throw error
        }
        for id in ids { assets[id] = nil }
        return existing.withLock { $0 }
    }

    // MARK: Existence

    func missingIDs(among ids: [String]) async -> Set<String> {
        guard accessLevel == .authorized, !ids.isEmpty else { return [] }
        return await Self.findMissing(ids)
    }

    @concurrent
    private nonisolated static func findMissing(_ ids: [String]) async -> Set<String> {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var found = Set<String>()
        for index in 0..<fetched.count { found.insert(fetched.object(at: index).localIdentifier) }
        return Set(ids).subtracting(found)
    }

    // MARK: File size

    func byteSize(for id: String) -> Int64? {
        guard let asset = asset(for: id) else { return nil }
        return Self.fileSize(of: asset)
    }

    func byteSizes(for ids: [String]) async -> [String: Int64] {
        guard !ids.isEmpty else { return [:] }
        return await Self.readFileSizes(ids)
    }

    @concurrent
    private nonisolated static func readFileSizes(_ ids: [String]) async -> [String: Int64] {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var sizes: [String: Int64] = [:]
        for index in 0..<fetched.count {
            let asset = fetched.object(at: index)
            if let size = fileSize(of: asset) { sizes[asset.localIdentifier] = size }
        }
        return sizes
    }

    /// REVIEW RISK (App Store guideline 2.5.1): `fileSize` on `PHAssetResource` is an undocumented
    /// key read through KVC. It is isolated here and guarded: if the selector is missing or the
    /// value is not a number we return `nil` (the UI hides the size badge) and never crash.
    /// The selector name `fileSize` is also public API elsewhere (`NSDictionary`'s file attributes);
    /// only its use on `PHAssetResource` is private.
    /// Remove this function to drop the feature without touching anything else.
    private nonisolated static func fileSize(of asset: PHAsset) -> Int64? {
        let selector = NSSelectorFromString("fileSize")
        var total: Int64 = 0
        var found = false
        for resource in PHAssetResource.assetResources(for: asset) {
            guard resource.responds(to: selector),
                  let number = resource.value(forKey: "fileSize") as? NSNumber
            else { continue }
            total += number.int64Value
            found = true
        }
        return found ? total : nil
    }
}
