import AVFoundation
import Observation
import SwiftUI

/// Muted-by-default looping player for the front video card.
@Observable
final class LoopingPlayer {
    let player = AVQueuePlayer()
    private(set) var isReady = false
    @ObservationIgnored private var looper: AVPlayerLooper?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }

    func load(_ item: AVPlayerItem) {
        looper = AVPlayerLooper(player: player, templateItem: item)
        isReady = true
    }

    func play() { player.play() }
    func pause() { player.pause() }

    func tearDown() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        isReady = false
    }

    /// 0...1 through the loop.
    func progress(duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        let seconds = player.currentTime().seconds
        guard seconds.isFinite else { return 0 }
        return min(1, max(0, seconds.truncatingRemainder(dividingBy: duration) / duration))
    }
}

/// Bare `AVPlayerLayer`, filling its frame, with no system controls.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class View: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> View {
        let view = View()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: View, context: Context) {
        view.playerLayer.player = player
    }
}
