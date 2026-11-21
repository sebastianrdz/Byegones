import SwiftUI

/// The product: top bar, card stack, four glass buttons.
struct SwipeScreen: View {
    let session: SwipeSession
    let screenshot: ScreenshotMode?

    @State private var controller: CardController
    @State private var store: CardImageStore
    @State private var isMuted = true
    @State private var showSettings = false
    @State private var showTrash = false
    @State private var celebration: CelebrationSummary?
    @State private var pendingCelebration: CelebrationSummary?
    @State private var limitedBannerDismissed = false
    @State private var showsUndoAsUsed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var typeSize

    init(session: SwipeSession, screenshot: ScreenshotMode?) {
        self.session = session
        self.screenshot = screenshot
        _controller = State(initialValue: CardController(session: session))
        _store = State(initialValue: CardImageStore(library: session.library))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if session.access == .limited && !limitedBannerDismissed {
                LimitedBanner(
                    onChange: {
                        Task {
                            await LimitedLibraryPicker.present()
                            await session.load()
                        }
                    },
                    onDismiss: { limitedBannerDismissed = true }
                )
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
            }
            content
        }
        .background(Color.canvas.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: controller.thresholdTick)
        .sensoryFeedback(trigger: controller.haptic) { _, new in
            switch new.kind {
            case .none: nil
            case .keep: .impact(weight: .light, intensity: 0.6)
            case .delete: .impact(weight: .medium)
            case .favorite: .success
            case .undo: .impact(flexibility: .rigid, intensity: 0.5)
            }
        }
        .onChange(of: reduceMotion, initial: true) { _, value in controller.reduceMotion = value }
        .onChange(of: session.queue.first?.id, initial: true) {
            for item in session.queue.prefix(3) { store.ensure(item) }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(session: session)
        }
        .sheet(isPresented: $showTrash, onDismiss: {
            if let pending = pendingCelebration {
                pendingCelebration = nil
                celebration = pending
            }
        }) {
            TrashSheet(session: session) { summary in pendingCelebration = summary }
        }
        .fullScreenCover(item: $celebration) { summary in
            CelebrationView(summary: summary, isScreenshot: screenshot != nil) { celebration = nil }
        }
        .task { await runScreenshotScene() }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !session.hasLoaded {
            SkeletonCards()
                .padding(.horizontal, Space.m)
                .padding(.top, Space.m)
                .padding(.bottom, Space.l)
            Spacer().frame(height: 72 + Space.m)
        } else if session.current != nil {
            cardArea
            actionBar
        } else {
            EmptyStateView(session: session, onReviewTrash: { showTrash = true }, onOpenSettings: { showSettings = true })
        }
    }

    private var cardArea: some View {
        CardStack(session: session, controller: controller, store: store, isMuted: $isMuted)
            .padding(.horizontal, Space.m)
            .padding(.top, Space.m)
            .padding(.bottom, Space.l)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                let card = CGSize(width: max(1, size.width - Space.m * 2), height: max(1, size.height - Space.m - Space.l))
                controller.cardSize = card
                let pixels = CGSize(width: (card.width * displayScale).rounded(), height: (card.height * displayScale).rounded())
                store.targetSize = pixels
                session.prefetchTargetSize = pixels
            }
    }

    private var actionBar: some View {
        GlassGroup(spacing: 16) {
            HStack(spacing: 16) {
                ActionButton(
                    symbol: "arrow.uturn.backward", glyphSize: 22, diameter: 56, color: .undoGlyph,
                    label: "swipe.button.undo.label", hint: "swipe.button.undo.hint",
                    isEnabled: session.canUndo && !controller.isBusy, showsAsUsed: showsUndoAsUsed
                ) { controller.undo() }
                ActionButton(
                    symbol: "xmark", glyphSize: 30, diameter: 72, color: .deleteGlyph,
                    label: "swipe.button.delete.label", hint: "swipe.button.delete.hint"
                ) { controller.perform(.trash) }
                ActionButton(
                    symbol: "star.fill", glyphSize: 24, diameter: 56, color: .favoriteGlyph,
                    label: "swipe.button.favorite.label", hint: "swipe.button.favorite.hint"
                ) { controller.perform(.favorite) }
                ActionButton(
                    symbol: "checkmark", glyphSize: 30, diameter: 72, color: .keepGlyph,
                    label: "swipe.button.keep.label", hint: "swipe.button.keep.hint"
                ) { controller.perform(.keep) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Space.m)
    }

    // MARK: Top bar

    private var compactBar: Bool { typeSize >= .accessibility1 }

    private var topBar: some View {
        HStack(spacing: Space.s) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, height: 44)
                    .glassSurface(in: Circle(), interactive: true)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(Text("settings.a11y.open"))

            Spacer(minLength: Space.s)
            counter
            Spacer(minLength: Space.s)
            trashPill
        }
        .padding(.horizontal, Space.l)
        .padding(.top, Space.xs)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private var counter: some View {
        GlassGroup {
            Group {
                if !session.hasLoaded {
                    ProgressView()
                } else if compactBar {
                    Text("\(session.remainingCount)")
                } else {
                    Text(Strings.counter(session.remainingCount))
                }
            }
            .font(.rounded(.subheadline, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Color.ink)
            .contentTransition(.numericText())
            .padding(.horizontal, Space.l)
            .frame(minHeight: 36)
            .glassSurface(in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Strings.counterA11y(session.remainingCount)))
        }
    }

    private var trashPill: some View {
        let count = session.pendingTrash.count
        let bytes: Int64? = session.pendingTrashHasSizes ? session.pendingTrashBytes : nil
        return Button { showTrash = true } label: {
            Group {
                if count == 0 {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 44, height: 44)
                } else {
                    HStack(spacing: Space.xs + 2) {
                        Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                        Text(compactBar ? "\(count)" : Strings.trashPill(count: count, bytes: bytes))
                            .font(.rounded(.subheadline, weight: .semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Space.m + 2)
                    .frame(minHeight: 44)
                }
            }
            .glassSurface(in: Capsule(), interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .animation(.snappy, value: count)
        .accessibilityLabel(Text(Strings.trashPillA11y(count: count, bytes: bytes)))
    }

    // MARK: Screenshot scenes

    private func runScreenshotScene() async {
        guard let screenshot else { return }
        var waited = 0
        while !session.hasLoaded && waited < 100 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        guard session.hasLoaded else { return }
        switch screenshot.scene {
        case .onboarding, .swipe:
            break
        case .keep:
            try? await Task.sleep(for: .milliseconds(600))
            controller.hold(.keep)
        case .favorite:
            try? await Task.sleep(for: .milliseconds(600))
            controller.hold(.favorite)
        case .undo:
            session.keep()
            session.keep()
            session.undo()
            showsUndoAsUsed = true
            try? await Task.sleep(for: .milliseconds(600))
            controller.showUndone(.keep)
        case .settings:
            try? await Task.sleep(for: .milliseconds(400))
            showSettings = true
        case .trash:
            for _ in 0..<8 { session.trash() }
            try? await Task.sleep(for: .milliseconds(400))
            showTrash = true
        case .celebration:
            for _ in 0..<8 { session.trash() }
            if case .deleted(let count, let bytes) = await session.commitTrash() {
                celebration = CelebrationSummary(
                    count: count, bytes: bytes, lifetime: session.bytesFreed, queueIsEmpty: session.current == nil
                )
            }
        }
    }
}

struct LimitedBanner: View {
    let onChange: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GlassGroup {
            HStack(spacing: Space.s) {
                Image(systemName: "photo.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityHidden(true)
                Text("permission.limited.banner")
                    .font(.footnote)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("permission.limited.button", action: onChange)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.brand)
                    .frame(minHeight: 44)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("trash.close"))
            }
            .padding(.leading, Space.m)
            .frame(minHeight: 44)
            .glassSurface(in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        }
    }
}
