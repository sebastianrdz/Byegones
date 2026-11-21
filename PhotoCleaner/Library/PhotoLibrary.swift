import AVFoundation
@preconcurrency import Photos
import UIKit
import os

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

/// Moves a non-Sendable Photos result across the continuation. The value is used only by the
/// awaiting caller after the handler returns, so nothing is shared.
private nonisolated struct Handoff<T>: @unchecked Sendable {
    let value: T
}

final class PhotoLibrary: PhotoLibraryProviding {
    private let cachingManager = PHCachingImageManager()
    private var assetsByID: [String: PHAsset] = [:]

    // The caching manager only serves cache hits when requests use the same options object,
    // target size and content mode as startCaching.
    private let imageOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        return options
    }()

    private let videoOptions: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        return options
    }()

    // MARK: Authorization

    var accessLevel: LibraryAccess {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

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
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue
        )
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let result = PHAsset.fetchAssets(with: options)
        var items: [MediaItem] = []
        var cache: [String: PHAsset] = [:]
        items.reserveCapacity(result.count)
        cache.reserveCapacity(result.count)
        for index in 0..<result.count {
            let asset = result.object(at: index)
            cache[asset.localIdentifier] = asset
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
        assetsByID = cache
        return items
    }

    private func asset(for id: String) -> PHAsset? {
        if let cached = assetsByID[id] { return cached }
        guard let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return nil
        }
        assetsByID[id] = fetched
        return fetched
    }

    // MARK: Loading media

    func image(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = asset(for: id) else { return nil }
        let options = imageOptions
        let manager = cachingManager
        let once = ResumeOnce()
        return await withCheckedContinuation { continuation in
            // Explicitly @Sendable: Photos may call back off the main actor.
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) {
                @Sendable image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if degraded && image != nil { return }
                if once.claim() { continuation.resume(returning: image) }
            }
        }
    }

    func playerItem(for id: String) async -> AVPlayerItem? {
        guard let asset = asset(for: id) else { return nil }
        let options = videoOptions
        let manager = cachingManager
        let once = ResumeOnce()
        let boxed: Handoff<AVPlayerItem?> = await withCheckedContinuation { continuation in
            manager.requestPlayerItem(forVideo: asset, options: options) { @Sendable item, _ in
                if once.claim() { continuation.resume(returning: Handoff(value: item)) }
            }
        }
        return boxed.value
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        cachingManager.stopCachingImagesForAllAssets()
        let assets = ids.compactMap { asset(for: $0) }
        guard !assets.isEmpty else { return }
        cachingManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFit, options: imageOptions)
    }

    func stopCaching() {
        cachingManager.stopCachingImagesForAllAssets()
    }

    // MARK: Changes

    func setFavorite(_ isFavorite: Bool, forID id: String) async throws {
        // Re-fetch inside the block so only a String crosses into the @Sendable closure.
        try await PHPhotoLibrary.shared().performChanges {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return }
            PHAssetChangeRequest(for: asset).isFavorite = isFavorite
        }
    }

    func delete(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                PHAssetChangeRequest.deleteAssets(assets)
            }
        } catch {
            // PHPhotosError.userCancelled == 3072.
            if (error as NSError).code == PHPhotosError.userCancelled.rawValue {
                throw PhotoLibraryError.userCancelled
            }
            throw error
        }
        for id in ids { assetsByID[id] = nil }
    }

    // MARK: File size

    /// REVIEW RISK (App Store guideline 2.5.1): `fileSize` on `PHAssetResource` is an undocumented
    /// key read through KVC. It is isolated here and guarded: if the selector is missing or the
    /// value is not a number we return `nil` (the UI hides the size badge) and never crash.
    /// Remove this function to drop the feature without touching anything else.
    func byteSize(for id: String) -> Int64? {
        guard let asset = asset(for: id) else { return nil }
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
