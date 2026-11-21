import AVFoundation
import SwiftUI

/// One photo or video card. Role (front / next) and motion are applied by `CardStack`.
struct CardView: View {
    let item: MediaItem
    let isTop: Bool
    let session: SwipeSession
    let controller: CardController
    let store: CardImageStore
    @Binding var isMuted: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var video: LoopingPlayer?
    @State private var userStartedVideo = false
    @State private var hintOpacity = 0.0

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.card, style: .continuous) }

    private var autoplayAllowed: Bool {
        UIAccessibility.isVideoAutoplayEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var shouldPlay: Bool {
        isTop && item.kind == .video && scenePhase == .active
            && controller.departing == nil && !controller.isDragging
            && (autoplayAllowed || userStartedVideo)
    }

    var body: some View {
        ZStack {
            shape.fill(Color.surface)
            photoLayer
            if isTop, let video, video.isReady, item.kind == .video {
                PlayerLayerView(player: video.player)
            }
            stateOverlays
            if isTop { chrome }
        }
        .clipShape(shape)
        .overlay { if isTop { stampOverlay } }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.18), radius: 24, y: 10)
        .contentShape(shape)
        .onTapGesture { if item.kind == .video { toggleMute() } }
        .task { store.ensure(item) }
        .task(id: isTop) { await prepareVideo() }
        .onChange(of: shouldPlay) { _, play in
            if play { video?.play() } else { video?.pause() }
        }
        .onChange(of: isMuted) { _, muted in video?.isMuted = muted }
        .onDisappear { video?.tearDown(); video = nil }
    }

    // MARK: Layers

    private var photoLayer: some View {
        Color.clear.overlay {
            if let image = store.images[item.id] {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let thumb = store.thumbnails[item.id] {
                Image(uiImage: thumb).resizable().scaledToFill()
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var stateOverlays: some View {
        if store.images[item.id] == nil, store.failed.contains(item.id) {
            VStack(spacing: Space.m) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                Text("error.load.photo")
                    .font(.body)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                Button("error.retry") { store.retry(item) }
                    .font(.rounded(.headline, weight: .semibold))
                    .frame(minHeight: 44)
            }
            .padding(Space.xl)
        } else if store.downloading.contains(item.id) {
            Label("swipe.loading.icloud", systemImage: "icloud.and.arrow.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.s)
                .glassSurface(in: Capsule())
        }
    }

    private var stampOverlay: some View {
        let progress = controller.stampProgress
        return Group {
            if let kind = controller.stampKind {
                StampView(action: kind)
                    .opacity(progress)
                    .scaleEffect(0.88 + 0.12 * progress)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: stampAlignment(kind))
                    .padding(28)
            }
        }
        .allowsHitTesting(false)
    }

    private func stampAlignment(_ kind: DecisionAction) -> Alignment {
        switch kind {
        case .keep: .topLeading
        case .trash: .topTrailing
        case .favorite: .top
        }
    }

    // MARK: Chrome on the front card

    private var chrome: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                metadata
            }
            if item.kind == .video { videoChrome }
        }
    }

    private var metadata: some View {
        let hidden = controller.stampProgress > 0.3
        let size = session.byteSize(of: item)
        return VStack(alignment: .leading, spacing: Space.xxs) {
            if let date = item.creationDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
            }
            if size != nil || item.kind == .video {
                Text(metaLine(size: size))
                    .font(.rounded(.footnote, weight: .medium))
                    .monospacedDigit()
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .padding(.top, Space.xxl)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, Color.scrim], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
        }
        .opacity(hidden ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: hidden)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func metaLine(size: Int64?) -> String {
        var parts: [String] = []
        if let size { parts.append(ByteFormat.string(size)) }
        if item.kind == .video { parts.append(DurationFormat.string(item.duration)) }
        return parts.joined(separator: " · ")
    }

    private var videoChrome: some View {
        ZStack {
            Image(systemName: "video.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(width: 36, height: 28)
                .glassSurface(in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Space.l)
                .accessibilityHidden(true)

            if autoplayAllowed || userStartedVideo {
                Button(action: toggleMute) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: isMuted)
                        .frame(width: 44, height: 44)
                        .glassSurface(in: Circle(), interactive: true)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(Text(isMuted ? "swipe.video.unmute" : "swipe.video.mute"))
                .accessibilityHint(Text("swipe.video.hint"))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(Space.l)
                .padding(.bottom, Space.xs)
            } else {
                Button { userStartedVideo = true } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(Text("swipe.video.play"))
            }

            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 8)
                .opacity(hintOpacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if shouldPlay, let video {
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    GeometryReader { proxy in
                        let value = video.progress(duration: item.duration)
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.white.opacity(0.4))
                            Rectangle().fill(.white.opacity(0.9)).frame(width: proxy.size.width * value)
                        }
                    }
                    .frame(height: 3)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    // MARK: Video

    private func prepareVideo() async {
        guard isTop, item.kind == .video else {
            video?.tearDown()
            video = nil
            return
        }
        let player = video ?? LoopingPlayer()
        video = player
        guard !player.isReady, let playerItem = await session.library.playerItem(for: item.id) else { return }
        guard !Task.isCancelled else { return }
        player.load(playerItem)
        player.isMuted = isMuted
        if shouldPlay { player.play() }
    }

    private func toggleMute() {
        isMuted.toggle()
        video?.isMuted = isMuted
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { hintOpacity = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.easeOut(duration: 0.6)) { hintOpacity = 0 }
        }
    }
}
