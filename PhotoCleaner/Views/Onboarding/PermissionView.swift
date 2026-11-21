import SwiftUI

/// Full-screen takeover for every access state that is not "can read".
struct PermissionView: View {
    let session: SwipeSession

    var body: some View {
        Group {
            switch session.access {
            case .restricted:
                message(title: "permission.restricted.title", body: "permission.restricted.body")
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Space.huge) }
            case .denied:
                message(title: "permission.denied.title", body: "permission.denied.body")
                    .safeAreaInset(edge: .bottom) {
                        Button { SystemSettings.open() } label: { Text("permission.denied.button") }
                            .buttonStyle(.primary)
                            .padding(.horizontal, Space.l)
                            .padding(.bottom, Space.xl)
                    }
            default:
                OnboardingPage(title: "onboarding.page3.title", message: "onboarding.page3.body") {
                    PromptIcon(symbol: "photo.on.rectangle.angled")
                }
                .safeAreaInset(edge: .bottom) {
                    Button { Task { await session.start() } } label: { Text("onboarding.allow") }
                        .buttonStyle(.primary)
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.xl)
                }
            }
        }
        .background(Color.canvas.ignoresSafeArea())
    }

    private func message(title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        ScrollView {
            VStack(spacing: Space.m) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.bottom, Space.s)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.rounded(.title2, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(body)
                    .font(.body)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity, minHeight: 480)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
