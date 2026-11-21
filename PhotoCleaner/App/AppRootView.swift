import SwiftUI

/// Chooses between onboarding, permission takeovers and the swipe screen, and keeps the library
/// in sync with the app lifecycle.
struct AppRootView: View {
    let session: SwipeSession
    let screenshot: ScreenshotMode?

    @AppStorage(DefaultsKey.onboardingComplete) private var onboardingComplete = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var reloadTask: Task<Void, Never>?

    private var showsOnboarding: Bool {
        if let screenshot { return screenshot.scene == .onboarding }
        return !onboardingComplete
    }

    var body: some View {
        Group {
            if showsOnboarding {
                OnboardingView(session: session) { onboardingComplete = true }
            } else {
                switch session.access {
                case .limited, .authorized:
                    SwipeScreen(session: session, screenshot: screenshot)
                case .notDetermined, .denied, .restricted:
                    PermissionView(session: session)
                }
            }
        }
        .task {
            // Screenshot runs have no one to tap Allow: resolve the (pre-granted) permission directly.
            if let screenshot, screenshot.scene != .onboarding {
                await session.start()
            } else {
                await session.load()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Debounced: permission prompts and app switches flip the phase repeatedly.
                reloadTask?.cancel()
                reloadTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await session.load()
                }
            case .background:
                Task { await session.flush() }
            default:
                break
            }
        }
    }
}
