import AVFoundation
import SwiftUI

@main
struct PhotoCleanerApp: App {
    @State private var session: SwipeSession
    private let screenshot = ScreenshotMode.current

    init() {
        // Video plays muted by default and must not interrupt the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)

        Self.resetIfRequested()

        if let screenshotMode = ScreenshotMode.current {
            // Screenshot mode reads the real library, never writes to it, and starts from a clean slate.
            let progress = FileManager.default.temporaryDirectory
                .appending(path: "screenshot-\(UUID().uuidString).json", directoryHint: .notDirectory)
            _session = State(initialValue: SwipeSession(
                library: ScreenshotPhotoLibrary(base: PhotoLibrary(), failWrites: screenshotMode.failsWrites),
                store: ProgressStore(fileURL: progress)
            ))
        } else {
            _session = State(initialValue: SwipeSession(library: PhotoLibrary()))
        }
    }

    /// Test hook: `-resetProgress YES` clears saved progress, the onboarding flag and the review
    /// flag before anything reads them. Compiled into Debug builds only, so Release ignores it.
    private static func resetIfRequested() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-resetProgress"), args.indices.contains(index + 1),
              ["YES", "yes", "true", "1"].contains(args[index + 1]) else { return }
        let store = ProgressStore()
        try? FileManager.default.removeItem(at: store.fileURL)
        try? FileManager.default.removeItem(at: store.corruptFileURL)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.onboardingComplete)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.reviewRequested)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(session: session, screenshot: screenshot)
        }
    }
}
