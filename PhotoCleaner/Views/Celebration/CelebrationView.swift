import StoreKit
import SwiftUI

struct CelebrationView: View {
    let summary: CelebrationSummary
    let isScreenshot: Bool
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = 72
    /// Nil until the cover has finished sliding in, so the count shows 0 until then.
    @State private var startDate: Date?
    @State private var countUpFinished = false
    @State private var confettiStarted = false

    private let countUpDuration = 0.9
    /// The full-screen cover takes about this long to arrive. Motion that starts at `onAppear`
    /// would play its first third behind the transition. Screenshots start at once.
    private var entranceDelay: Double { isScreenshot ? 0 : 0.35 }
    /// Below 1 MB the item count is the headline (and for unknown sizes, which arrive as 0).
    private var showsSize: Bool { bytes >= 1_000_000 }

    /// The amount on screen. Debug builds accept `-celebrationBytes <n>` so the layout can be
    /// checked at any size (33.5 MB, 1.24 GB) without deleting anything.
    private var bytes: Int64 {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "celebrationBytes"), let value = Int64(raw) { return value }
        #endif
        return summary.bytes
    }

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
            if !reduceMotion && confettiStarted { ConfettiBurst().padding(.top, 220) }
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
        .task {
            try? await Task.sleep(for: .seconds(entranceDelay))
            confettiStarted = true
            startDate = .now
            try? await Task.sleep(for: .seconds(countUpDuration + 0.1))
            countUpFinished = true
        }
        .task { await maybeRequestReview() }
    }

    // MARK: Hero

    @ViewBuilder
    private var hero: some View {
        if showsSize {
            let full = Strings.celebrationTitle(bytes: bytes)
            TimelineView(.animation(paused: reduceMotion || countUpFinished)) { context in
                // The final text is laid out invisibly underneath, so the line breaks, the scale
                // factor and the centring are those of the end state from the first frame.
                ZStack {
                    heroLabel(progress: 1).hidden()
                    heroLabel(progress: progress(at: context.date))
                }
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

    /// The lead-in ("You cleared") on its own line above a one-line hero ("33.5 MB!"). The hero
    /// scales down before it would ever wrap, so the number, its unit and the "!" never separate.
    private func heroLabel(progress: Double) -> some View {
        let parts = Self.heroParts(bytes: Int64(Double(bytes) * progress))
        return VStack(spacing: Space.xs) {
            if !parts.lead.isEmpty {
                Text(parts.lead)
                    .font(.rounded(.title2, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }
            Text(parts.hero)
                .font(Font.system(size: heroSize, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
        }
        .multilineTextAlignment(.center)
    }

    /// Splits the localized title around the size: the words before it, and the size joined to
    /// whatever follows it with a no-break space and a word joiner.
    static func heroParts(bytes: Int64) -> (lead: String, hero: String) {
        let size = ByteFormat.string(bytes)
        let full = Strings.celebrationTitle(bytes: bytes)
        guard let range = full.range(of: size) else { return ("", full) }
        let lead = full[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
        let tail = full[range.upperBound...]
        let unbroken = size.replacingOccurrences(of: " ", with: "\u{00A0}")
        return (lead, tail.isEmpty ? unbroken : unbroken + "\u{2060}" + tail)
    }

    private func progress(at date: Date) -> Double {
        if reduceMotion { return 1 }
        guard let startDate else { return 0 }
        let t = min(1, max(0, date.timeIntervalSince(startDate) / countUpDuration))
        return 1 - pow(1 - t, 3)
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
