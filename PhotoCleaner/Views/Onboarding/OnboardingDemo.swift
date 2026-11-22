import SwiftUI

/// The one decorative loop: a demo card swiped right, left and up, with a caption naming each
/// gesture. Reduce Motion cross-fades through three still states, once.
struct OnboardingDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var offset = CGSize.zero
    @State private var rotation = 0.0
    @State private var stamp: DecisionAction?
    @State private var stampProgress = 0.0
    @State private var cardOpacity = 1.0
    @State private var cardScale = 1.0
    @State private var caption: DecisionAction = .keep

    private let width: CGFloat = 240
    private let height: CGFloat = 320

    var body: some View {
        VStack(spacing: Space.l) {
            ZStack {
                DemoPhoto(width: width, height: height)
                    .scaleEffect(0.94)
                    .offset(y: 14)
                    .opacity(0.55)

                DemoPhoto(width: width, height: height)
                    .overlay {
                        if let stamp {
                            StampView(action: stamp)
                                // Reduce Motion swaps stamps by cross-fading, never by sliding.
                                .id(stamp)
                                .transition(reduceMotion ? .opacity : .identity)
                                .opacity(stampProgress)
                                .scaleEffect(0.88 + 0.12 * stampProgress)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(stamp))
                                .padding(20)
                        }
                    }
                    .scaleEffect(cardScale)
                    .offset(offset)
                    .rotationEffect(.degrees(rotation))
                    .opacity(cardOpacity)
            }
            .frame(width: width + 80, height: height + 40)

            Label {
                Text(captionKey)
            } icon: {
                Image(systemName: caption.symbol)
            }
            .font(.rounded(.headline, weight: .semibold))
            .foregroundStyle(caption.glyphColor)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: caption)
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.page1.demo.a11y"))
        .task { await run() }
    }

    private var captionKey: LocalizedStringKey {
        switch caption {
        case .keep: "onboarding.page1.demo.keep"
        case .trash: "onboarding.page1.demo.delete"
        case .favorite: "onboarding.page1.demo.favorite"
        }
    }

    private func alignment(_ action: DecisionAction) -> Alignment {
        switch action {
        case .keep: .topLeading
        case .trash: .topTrailing
        case .favorite: .top
        }
    }

    // MARK: Loop

    private func run() async {
        if ScreenshotMode.current != nil {
            // Deterministic frame for App Store screenshots.
            caption = .keep
            stamp = .keep
            stampProgress = 0.95
            // Composed pose, fully on screen with margin on both sides.
            offset = CGSize(width: 24, height: 4)
            rotation = 2.5
            return
        }
        // Start every pass from the resting first frame: a page that is left mid-loop and
        // revisited must not spring back from wherever it was cancelled.
        var rest = Transaction(); rest.disablesAnimations = true
        withTransaction(rest) {
            offset = .zero; rotation = 0; stamp = nil; stampProgress = 0
            cardOpacity = 1; cardScale = 1; caption = .keep
        }
        if reduceMotion { await runStill(); return }
        let sequence: [DecisionAction] = [.keep, .trash, .favorite]
        try? await Task.sleep(for: .milliseconds(600))
        while !Task.isCancelled {
            for action in sequence {
                caption = action
                let sign: CGFloat = action == .keep ? 1 : -1
                stamp = action
                // Drift toward the decision; the stamp reveals as the card moves.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    stampProgress = 0.95
                    switch action {
                    case .favorite: offset = CGSize(width: 0, height: -90)
                    default: offset = CGSize(width: sign * 84, height: 10); rotation = Double(sign) * 4.5
                    }
                }
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                // Fly off.
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 170, damping: 24)) {
                    stampProgress = 1
                    if action == .favorite {
                        offset = CGSize(width: 0, height: -height * 1.2)
                    } else {
                        offset = CGSize(width: sign * width * 1.5, height: 10)
                        rotation = Double(sign) * 22
                    }
                }
                try? await Task.sleep(for: .milliseconds(380))
                // A fresh card rises into place.
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) {
                    offset = .zero; rotation = 0; stamp = nil; stampProgress = 0
                    cardScale = 0.94; cardOpacity = 0
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cardScale = 1; cardOpacity = 1
                }
                try? await Task.sleep(for: .milliseconds(800))
            }
            try? await Task.sleep(for: .milliseconds(800))
        }
    }

    private func runStill() async {
        for action in [DecisionAction.keep, .trash, .favorite] {
            withAnimation(.easeInOut(duration: 0.18)) {
                caption = action
                stamp = action
                stampProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
        }
        withAnimation(.easeInOut(duration: 0.18)) { stamp = nil; stampProgress = 0 }
    }
}

/// Abstract sunset with two hills. Illustration, not a photo.
struct DemoPhoto: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [DemoArt.skyTop, DemoArt.skyMid, DemoArt.skyLow], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(DemoArt.skyLow.opacity(0.9))
                .frame(width: 70, height: 70)
                .offset(x: 40, y: -120)
            Ellipse()
                .fill(DemoArt.hillFar)
                .frame(width: 320, height: 150)
                .offset(x: -60, y: 70)
            Ellipse()
                .fill(DemoArt.hillNear)
                .frame(width: 300, height: 130)
                .offset(x: 70, y: 70)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }
}
