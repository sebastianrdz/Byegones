import Observation
import SwiftUI

/// Owns the card physics: drag, fly-off, snap-back and undo. The gesture, the four buttons and
/// the VoiceOver actions all go through `perform(_:)` / `undo()`.
@Observable
final class CardController {
    // MARK: Visual state of the moving card
    private(set) var offset: CGSize = .zero
    private(set) var rotation: Double = 0
    /// 0...1: how far the next card has risen toward the front.
    private(set) var peek: CGFloat = 0
    private(set) var stampKind: DecisionAction?
    /// Decision progress `p` (stamp opacity, stamp scale).
    private(set) var stampProgress: Double = 0
    private(set) var movingOpacity: Double = 1
    /// The card that has just been decided and is still flying out.
    private(set) var departing: MediaItem?
    private(set) var isBusy = false
    private(set) var isDragging = false

    // MARK: Haptic triggers (one event per trigger, never stacked)
    private(set) var thresholdTick = 0
    private(set) var haptic = Haptic(kind: .none, serial: 0)

    struct Haptic: Equatable {
        enum Kind: Equatable { case none, keep, delete, favorite, undo }
        var kind: Kind
        var serial: Int
    }

    // MARK: Inputs set by the view
    @ObservationIgnored var cardSize = CGSize(width: 340, height: 560)
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored private let session: SwipeSession
    @ObservationIgnored private var pastThreshold = false

    init(session: SwipeSession) {
        self.session = session
    }

    // MARK: Drag

    func dragChanged(_ translation: CGSize) {
        guard !isBusy, session.current != nil else { return }
        isDragging = true
        var dy = translation.height
        if dy > 0 {
            dy = min(40, dy * 0.3)
        } else {
            dy = max(dy, -cardSize.height * 0.5)
        }
        offset = CGSize(width: translation.width, height: dy)
        rotation = reduceMotion ? 0 : min(15, max(-15, translation.width / 20))
        let (kind, p) = classify(translation)
        stampKind = p > 0 ? kind : nil
        stampProgress = p
        peek = reduceMotion ? 0 : p

        let past = p >= 1
        if past != pastThreshold {
            pastThreshold = past
            thresholdTick += 1
        }
    }

    func dragEnded(translation: CGSize, predictedEnd: CGSize, velocity: CGSize) {
        guard !isBusy else { return }
        isDragging = false
        pastThreshold = false
        let (_, p) = classify(translation)
        let upDominant = abs(translation.height) > abs(translation.width) && translation.height < 0

        var action: DecisionAction?
        if upDominant {
            if p >= 1 || -predictedEnd.height > cardSize.height * 0.30 { action = .favorite }
        } else {
            let direction: CGFloat = predictedEnd.width != 0 ? (predictedEnd.width > 0 ? 1 : -1) : (translation.width >= 0 ? 1 : -1)
            if p >= 1 || abs(predictedEnd.width) > cardSize.width * 0.35 {
                action = direction > 0 ? .keep : .trash
            }
        }
        if let action {
            flyOff(action, velocity: velocity, predictedEnd: predictedEnd, fromDrag: true)
        } else {
            snapBack()
        }
    }

    private func classify(_ t: CGSize) -> (DecisionAction, Double) {
        if abs(t.height) > abs(t.width), t.height < 0 {
            return (.favorite, min(1, max(0, Double(-t.height / 120))))
        }
        let p = min(1, max(0, Double(abs(t.width) / 110)))
        return (t.width >= 0 ? .keep : .trash, p)
    }

    // MARK: Commit

    /// Button, VoiceOver action or gesture commit.
    func perform(_ action: DecisionAction) {
        guard !isBusy, session.current != nil else { return }
        isBusy = true
        // The stamp reaches full opacity before the card leaves.
        withAnimation(.easeOut(duration: 0.08)) {
            stampKind = action
            stampProgress = 1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            isBusy = false
            flyOff(action, velocity: .zero, predictedEnd: .zero, fromDrag: false)
        }
    }

    private func flyOff(_ action: DecisionAction, velocity: CGSize, predictedEnd: CGSize, fromDrag: Bool) {
        guard let item = session.current else { reset(); return }
        isBusy = true
        isDragging = false
        departing = item
        stampKind = action

        let sign: CGFloat = action == .keep ? 1 : -1
        let target: CGSize
        let endRotation: Double
        if action == .favorite {
            target = CGSize(width: offset.width, height: -(cardSize.height * 1.2))
            endRotation = 0
        } else {
            target = CGSize(width: sign * cardSize.width * 1.5, height: offset.height + (fromDrag ? predictedEnd.height * 0.4 : 0))
            endRotation = Double(sign) * 22
        }

        switch action {
        case .keep: session.keep()
        case .trash: session.trash()
        case .favorite: session.favorite()
        }
        emitHaptic(action)
        announce(action)

        if reduceMotion {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { peek = 1; stampProgress = 1 }
            withAnimation(.easeOut(duration: 0.18)) {
                movingOpacity = 0
            } completion: { [self] in reset() }
        } else {
            let distance = max(1, hypot(target.width - offset.width, target.height - offset.height))
            let speed = hypot(velocity.width, velocity.height)
            let spring = Animation.interpolatingSpring(mass: 1, stiffness: 170, damping: 24, initialVelocity: Double(speed / distance))
            withAnimation(spring) {
                offset = target
                rotation = endRotation
                peek = 1
                stampProgress = 1
            } completion: { [self] in reset() }
        }
    }

    private func snapBack() {
        let animation: Animation = reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.72)
        withAnimation(animation) {
            offset = .zero
            rotation = 0
            peek = 0
            stampProgress = 0
        } completion: { [self] in
            if !isDragging { stampKind = nil }
        }
    }

    // MARK: Undo

    func undo() {
        guard !isBusy, let decision = session.history.last else { return }
        isBusy = true
        let action = decision.action
        let sign: CGFloat = action == .keep ? 1 : -1
        session.undo()
        emit(.undo)
        AccessibilityNotification.Announcement(String(localized: "swipe.announce.undone", defaultValue: "Undone.")).post()

        // The restored card starts at the transform it left with, stamp visible, then returns.
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            stampKind = action
            if reduceMotion {
                offset = .zero; rotation = 0; peek = 0; stampProgress = 0; movingOpacity = 0
            } else if action == .favorite {
                offset = CGSize(width: 0, height: -(cardSize.height * 1.2)); rotation = 0; peek = 1; stampProgress = 1
            } else {
                offset = CGSize(width: sign * cardSize.width * 1.5, height: 0); rotation = Double(sign) * 22; peek = 1; stampProgress = 1
            }
        }
        Task {
            // One frame so the start transform is rendered before the spring runs.
            try? await Task.sleep(for: .milliseconds(24))
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.18)) { movingOpacity = 1 } completion: { [self] in reset() }
            } else {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                    offset = .zero; rotation = 0; peek = 0; stampProgress = 0
                } completion: { [self] in reset() }
            }
        }
    }

    // MARK: Screenshot scenes

    /// Holds the card mid-drag with a stamp visible, without any gesture.
    func hold(_ action: DecisionAction) {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            stampKind = action
            stampProgress = 0.92
            peek = 0.92
            switch action {
            case .keep: offset = CGSize(width: 76, height: 14); rotation = 3.8
            case .trash: offset = CGSize(width: -76, height: 14); rotation = -3.8
            case .favorite: offset = CGSize(width: 0, height: -64); rotation = 0
            }
        }
    }

    /// The moment right after an undo: card home, faint stamp of what was reverted.
    func showUndone(_ action: DecisionAction) {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            stampKind = action
            stampProgress = 0.55
            peek = 0.12
            offset = CGSize(width: action == .keep ? 14 : (action == .trash ? -14 : 0), height: action == .favorite ? -10 : 0)
            rotation = 0
        }
    }

    // MARK: Plumbing

    private func reset() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            departing = nil
            offset = .zero
            rotation = 0
            peek = 0
            stampKind = nil
            stampProgress = 0
            movingOpacity = 1
            isBusy = false
            isDragging = false
        }
    }

    private func emitHaptic(_ action: DecisionAction) {
        switch action {
        case .keep: emit(.keep)
        case .trash: emit(.delete)
        case .favorite: emit(.favorite)
        }
    }

    private func emit(_ kind: Haptic.Kind) {
        haptic = Haptic(kind: kind, serial: haptic.serial + 1)
    }

    private func announce(_ action: DecisionAction) {
        let text: String
        switch action {
        case .keep: text = String(localized: "swipe.announce.kept", defaultValue: "Kept.")
        case .favorite: text = String(localized: "swipe.announce.favorited", defaultValue: "Favorited.")
        case .trash: text = Strings.trashedAnnouncement(count: session.pendingTrash.count)
        }
        AccessibilityNotification.Announcement(text).post()
    }
}
