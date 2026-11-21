import SafariServices
import SwiftUI

struct SettingsView: View {
    let session: SwipeSession

    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var safariURL: SafariItem?

    private struct SafariItem: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        return Strings.version(
            info?["CFBundleShortVersionString"] as? String ?? "1.0",
            info?["CFBundleVersion"] as? String ?? "1"
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if session.bytesFreed > 0 {
                        LabeledContent {
                            Text(ByteFormat.string(session.bytesFreed))
                                .monospacedDigit()
                        } label: {
                            Text("settings.lifetime.label")
                        }
                    }
                    Button(role: .destructive) { confirmReset = true } label: {
                        Text("settings.reset.button").foregroundStyle(Color.deleteGlyph)
                    }
                }

                Section {
                    Button { Task { await photosAccessTapped() } } label: {
                        LabeledContent {
                            HStack(spacing: Space.xs) {
                                Text(accessLabel).foregroundStyle(Color.inkSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                        } label: {
                            Text("settings.photos.label").foregroundStyle(Color.ink)
                        }
                    }
                }

                Section {
                    if let url = AppLinks.privacy, url.scheme == "https" {
                        Button { safariURL = SafariItem(url: url) } label: {
                            linkRow("settings.privacy")
                        }
                    }
                    if let url = AppLinks.support {
                        Link(destination: url) { linkRow("settings.support") }
                    }
                    if let url = AppLinks.writeReview {
                        Link(destination: url) { linkRow("settings.rate") }
                    }
                    LabeledContent {
                        EmptyView()
                    } label: {
                        Text(versionString).foregroundStyle(Color.inkSecondary)
                    }
                } footer: {
                    Text("settings.about.tagline")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
            .confirmationDialog(
                Text("settings.reset.confirm.title"),
                isPresented: $confirmReset,
                titleVisibility: .visible
            ) {
                Button("settings.reset.confirm.action", role: .destructive) {
                    Task {
                        await session.resetProgress()
                        AccessibilityNotification.Announcement(
                            String(localized: "settings.reset.done", defaultValue: "Progress reset.")
                        ).post()
                    }
                }
                Button("settings.reset.confirm.cancel", role: .cancel) {}
            } message: {
                Text("settings.reset.confirm.message")
            }
            .sheet(item: $safariURL) { item in
                SafariView(url: item.url).ignoresSafeArea()
            }
        }
        .presentationDetents([.large])
    }

    private func linkRow(_ key: LocalizedStringKey) -> some View {
        HStack {
            Text(key).foregroundStyle(Color.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inkTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
    }

    private var accessLabel: LocalizedStringKey {
        switch session.access {
        case .authorized: "settings.photos.full"
        case .limited: "settings.photos.limited"
        case .denied, .restricted, .notDetermined: "settings.photos.off"
        }
    }

    private func photosAccessTapped() async {
        if session.access == .limited {
            await LimitedLibraryPicker.present()
            await session.load()
        } else {
            SystemSettings.open()
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
