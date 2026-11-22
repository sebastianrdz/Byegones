import Foundation

/// Links that depend on decisions made later. Replace the placeholders in one place.
enum AppLinks {
    static let siteDomain = "{{SITE_DOMAIN}}"
    static let appStoreID = "{{APP_STORE_ID}}"

    // The host is percent-encoded so the unreplaced placeholder still forms a valid URL.
    private static var host: String { siteDomain.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? siteDomain }

    static var privacy: URL? { URL(string: "https://\(host)/privacy") }
    static var support: URL? { URL(string: "https://\(host)/support") }
    static var writeReview: URL? {
        let id = appStoreID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? appStoreID
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }
}

extension ScreenshotMode {
    /// Scenes that show an error state make Photos writes fail instead of no-op.
    var failsWrites: Bool { scene == .favoriteFailed || scene == .deleteFailed }
}

enum DefaultsKey {
    static let onboardingComplete = "hasCompletedOnboarding"
    static let reviewRequested = "hasRequestedReview"
}

/// Deterministic state for App Store screenshots. Enabled with
/// `-screenshotMode YES -screenshotScene <onboarding|privacy|swipe|keep|favorite|undo|trash|celebration|settings|favoriteFailed|deleteFailed>`.
/// Never writes to Photos: favorite and delete are no-ops, and progress goes to a throwaway file.
struct ScreenshotMode: Sendable {
    enum Scene: String, Sendable {
        case onboarding, privacy, swipe, keep, favorite, undo, trash, celebration, settings, favoriteFailed, deleteFailed
    }

    let scene: Scene

    /// Debug builds only: `scripts/screenshots.sh` builds Debug, so a shipped (Release) app has no
    /// screenshot mode at all.
    static let current: ScreenshotMode? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
            return args[index + 1]
        }
        guard let flag = value(after: "-screenshotMode"), ["YES", "yes", "true", "1"].contains(flag) else { return nil }
        let scene = value(after: "-screenshotScene").flatMap(Scene.init(rawValue:)) ?? .swipe
        return ScreenshotMode(scene: scene)
        #else
        return nil
        #endif
    }()
}
