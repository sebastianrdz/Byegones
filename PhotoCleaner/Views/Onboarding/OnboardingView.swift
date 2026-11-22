import SwiftUI

struct OnboardingView: View {
    let session: SwipeSession
    let onFinish: () -> Void

    @State private var page: Int
    @State private var isRequesting = false

    init(session: SwipeSession, initialPage: Int = 0, onFinish: @escaping () -> Void) {
        self.session = session
        self.onFinish = onFinish
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        TabView(selection: $page) {
            OnboardingPage(title: "onboarding.page1.title", message: "onboarding.page1.body") {
                OnboardingDemo()
            }
            .tag(0)
            OnboardingPage(title: "onboarding.page2.title", message: "onboarding.page2.body") {
                PrivacyVisual()
            }
            .tag(1)
            OnboardingPage(title: "onboarding.page3.title", message: "onboarding.page3.body") {
                PromptIcon(symbol: "photo.on.rectangle.angled")
            }
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
    }

    private var controls: some View {
        VStack(spacing: Space.m) {
            HStack(spacing: Space.s) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == page ? Color.brand : Color.hairline)
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Strings.pageIndicator(page + 1, of: 3)))

            if page < 2 {
                Button { withAnimation { page += 1 } } label: { Text("onboarding.next") }
                    .buttonStyle(.primary)
            } else {
                Button {
                    isRequesting = true
                    Task {
                        await session.start()
                        isRequesting = false
                        onFinish()
                    }
                } label: { Text("onboarding.allow") }
                .buttonStyle(.primary)
                .disabled(isRequesting)

                Button { onFinish() } label: { Text("onboarding.notnow") }
                    .font(.subheadline)
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.xl)
        .padding(.top, Space.s)
        .background(Color.canvas)
        .animation(.default, value: page)
    }
}

struct OnboardingPage<Visual: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder var visual: Visual

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                visual
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.xl)
                VStack(spacing: Space.m) {
                    Text(title)
                        .font(.rounded(.largeTitle, weight: .bold))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 320)
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct PromptIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 88, weight: .semibold))
            .foregroundStyle(Color.brand)
            .frame(height: 220)
            .accessibilityHidden(true)
    }
}

struct PrivacyVisual: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Color.hairline, lineWidth: 1).frame(width: 220, height: 220)
            Circle().strokeBorder(Color.hairline, lineWidth: 1).frame(width: 160, height: 160)
            Image(systemName: "lock.shield.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 88, weight: .semibold))
                .foregroundStyle(Color.brand)
        }
        .frame(height: 240)
        .accessibilityHidden(true)
    }
}
