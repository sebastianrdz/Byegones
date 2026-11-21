import AVFoundation
import SwiftUI

@main
struct PhotoCleanerApp: App {
    @State private var session: SwipeSession
    private let screenshot = ScreenshotMode.current

    init() {
        // Video plays muted by default and must not interrupt the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)

        if ScreenshotMode.current != nil {
            // Screenshot mode reads the real library, never writes to it, and starts from a clean slate.
            let progress = FileManager.default.temporaryDirectory
                .appending(path: "screenshot-\(UUID().uuidString).json", directoryHint: .notDirectory)
            _session = State(initialValue: SwipeSession(
                library: ScreenshotPhotoLibrary(base: PhotoLibrary()),
                store: ProgressStore(fileURL: progress)
            ))
        } else {
            _session = State(initialValue: SwipeSession(library: PhotoLibrary()))
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(session: session, screenshot: screenshot)
        }
    }
}
