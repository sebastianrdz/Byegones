import SwiftUI

/// Engine smoke-test UI. Replaced by the real screens in the UI package.
struct RootView: View {
    let session: SwipeSession
    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            switch session.access {
            case .notDetermined:
                ProgressView()
            case .denied, .restricted:
                Text("Photo access is off. Allow it in Settings to start.")
                    .multilineTextAlignment(.center)
                Button("Open Settings", action: openSettings)
            case .limited, .authorized:
                review
            }
        }
        .padding()
        .task { await session.start() }
    }

    @ViewBuilder
    private var review: some View {
        if session.isLoading {
            ProgressView()
        } else if let item = session.current {
            Text("\(session.remainingCount) left")
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: item.id) {
                image = nil
                image = await session.library.image(for: item.id, targetSize: CGSize(width: 1200, height: 1600))
            }
            if let size = session.byteSize(of: item) {
                Text(size.formatted(.byteCount(style: .file)))
            }
            HStack {
                Button("Undo") { session.undo() }.disabled(!session.canUndo)
                Button("Delete") { session.trash() }
                Button("Favorite") { session.favorite() }
                Button("Keep") { session.keep() }
            }
            .buttonStyle(.bordered)
        } else {
            Text("No more items to review.")
        }
        if !session.pendingTrash.isEmpty {
            Button("Delete \(session.pendingTrash.count) items") {
                Task { await session.commitTrash() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
