import SwiftUI

@main
struct PhotoCleanerApp: App {
    @State private var session = SwipeSession(library: PhotoLibrary())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await session.flush() } }
        }
    }
}
