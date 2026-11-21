import StoreKit
import SwiftUI

struct CelebrationView: View {
    let summary: CelebrationSummary
    let isScreenshot: Bool
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = 72
    @State private var startDate = Date.now
    @State private var countUpFinished = false

    private let countUpDuration = 0.9
    /// Below 1 MB the item count is the headline (and for unknown sizes, which arrive as 0).
    private var showsSize: Bool { summary.bytes >= 1_000_000 }

    var body: some View {
        VStack(spacing: Space.l) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.keepGlyph)
                .accessibilityHidden(true)

            hero
                .padding(.horizontal, Space.l)

            Text("celebration.body")
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if summary.lifetime > summary.bytes {
                Text(Strings.lifetime(bytes: summary.lifetime))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            if !reduceMotion { ConfettiBurst().padding(.top, 220) }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text(summary.queueIsEmpty ? "settings.done" : "celebration.continue")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.m)
        }
        .background(Color.canvas.ignoresSafeArea())
        .onAppear { startDate = .now }
        .task {
            try? await Task.sleep(for: .seconds(countUpDuration + 0.1))
            countUpFinished = true
        }
        .task { await maybeRequestReview() }
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        if showsSize {
            let full = Strings.celebrationTitle(bytes: summary.bytes)
            TimelineView(.animation(paused: reduceMotion || countUpFinished)) { context in
                Text(heroText(at: context.date))
                    .font(.rounded(.title, weight: .bold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(full))
            .accessibilityAddTraits(.isHeader)
        } else {
            Text(Strings.celebrationTitleNoSize(count: summary.count))
                .font(.rounded(.largeTitle, weight: .bold))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func heroText(at date: Date) -> AttributedString {
        var progress = 1.0
        if !reduceMotion {
            let t = min(1, max(0, date.timeIntervalSince(startDate) / countUpDuration))
            progress = 1 - pow(1 - t, 3)
        }
        let shown = Int64(Double(summary.bytes) * progress)
        let size = ByteFormat.string(shown)
        var text = AttributedString(Strings.celebrationTitle(bytes: shown))
        if let range = text.range(of: size) {
            text[range].font = .system(size: heroSize, weight: .bold, design: .rounded)
        }
        return text
    }

    // MARK: Review prompt

    /// Once, after the first cleanup of 100 MB or more; never from a button.
    private func maybeRequestReview() async {
        guard !isScreenshot, summary.bytes >= 100_000_000,
              !UserDefaults.standard.bool(forKey: DefaultsKey.reviewRequested) else { return }
        try? await Task.sleep(for: .milliseconds(800))
        guard !Task.isCancelled else { return }
        UserDefaults.standard.set(true, forKey: DefaultsKey.reviewRequested)
        requestReview()
    }
}

/// One burst of small rounded rectangles in the action colors. Plays once.
private struct ConfettiBurst: View {
    @State private var progress: CGFloat = 0

    private struct Piece: Identifiable {
        let id: Int
        let dx: CGFloat
        let dy: CGFloat
        let spin: Double
        let color: Color
    }

    private let pieces: [Piece] = {
        let colors: [Color] = [.keepFill, .deleteFill, .favoriteFill, .undoFill, .brand]
        return (0..<16).map { i in
            let angle = -Double.pi / 2 + (Double(i) - 7.5) / 16 * Double.pi * 1.5
            let radius = 110 + Double(i % 4) * 38
            return Piece(
                id: i,
                dx: CGFloat(cos(angle) * radius),
                dy: CGFloat(sin(angle) * radius) + 170,
                spin: Double(160 + i * 23) * (i.isMultiple(of: 2) ? 1 : -1),
                color: colors[i % colors.count]
            )
        }
    }()

    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(piece.color)
                    .frame(width: 8, height: 14)
                    .rotationEffect(.degrees(piece.spin * Double(progress)))
                    .offset(x: piece.dx * progress, y: piece.dy * progress)
                    .opacity(Double(1 - progress))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { withAnimation(.easeOut(duration: 1.4)) { progress = 1 } }
    }
}
