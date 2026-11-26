import SwiftUI

/// Chooses between onboarding, permission takeovers and the swipe screen, and keeps the library
/// in sync with the app lifecycle.
struct AppRootView: View {
    let session: SwipeSession
    let screenshot: ScreenshotMode?

    @AppStorage(DefaultsKey.onboardingComplete) private var onboardingComplete = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var reloadTask: Task<Void, Never>?
    @State private var backgroundFlush = BackgroundFlush()

    private var showsOnboarding: Bool {
        if let screenshot { return screenshot.scene == .onboarding || screenshot.scene == .privacy }
        return !onboardingComplete
    }

    var body: some View {
        Group {
            if showsOnboarding {
                OnboardingView(session: session, initialPage: screenshot?.scene == .privacy ? 1 : 0) { onboardingComplete = true }
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
            if let screenshot, screenshot.scene != .onboarding, screenshot.scene != .privacy {
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
                    // Only re-fetch when Photos reported a change or access changed.
                    await session.reloadIfNeeded()
                }
            case .background:
                // The last swipes must reach disk even if the system suspends the app right now.
                backgroundFlush.run { await session.flush() }
            default:
                break
            }
        }
    }
}

/// Keeps the process alive long enough to finish writing progress when the app goes to the background.
/// Every run holds its own background task and ends only that one, so overlapping flushes
/// (background, foreground, background again) never end each other's time.
@MainActor
final class BackgroundFlush {
    private final class Ticket {
        var identifier = UIBackgroundTaskIdentifier.invalid

        func end() {
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }

    func run(_ work: @escaping () async -> Void) {
        let ticket = Ticket()
        // UIKit calls the expiration handler on the main thread.
        ticket.identifier = UIApplication.shared.beginBackgroundTask(withName: "Byegones.flushProgress") {
            ticket.end()
        }
        Task {
            await work()
            ticket.end()
        }
    }
}
