import Observation
import SwiftUI

/// Owns the card physics: drag, fly-off, snap-back and undo. The gesture, the four buttons and
/// the VoiceOver actions all go through `perform(_:)` / `undo()`.
///
/// A decided card keeps its own pose (`leavers`) and animates out on its own spring, while the
/// front card is already the next one. Nothing waits for a fly-off: a new decision or an undo
/// arriving mid-flight is applied at once.
@Observable
final class CardController {
    /// A decided card flying out. Its pose is independent of the front card.
    struct Leaver: Identifiable, Equatable {
        let item: MediaItem
        let generation: Int
        var offset: CGSize
        var rotation: Double
        var stampKind: DecisionAction?
        var stampProgress: Double
        var opacity: Double
        var id: String { item.id }
    }

    // MARK: Visual state of the front card
    private(set) var offset: CGSize = .zero
    private(set) var rotation: Double = 0
    /// 0...1: how far the next card has risen toward the front while the front card is dragged.
    private(set) var peek: CGFloat = 0
    private(set) var stampKind: DecisionAction?
    /// Decision progress `p` (stamp opacity, stamp scale).
    private(set) var stampProgress: Double = 0
    private(set) var movingOpacity: Double = 1
    /// Cards that have just been decided and are still flying out, oldest first.
    private(set) var leavers: [Leaver] = []
    /// True while input to the front card is locked: the 80 ms button head start and the undo return.
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
    /// With Reduce Motion the next card sits at full size under the front card, so nothing pops
    /// when the front card fades out.
    @ObservationIgnored var reduceMotion = false {
        didSet {
            guard reduceMotion != oldValue, !isDragging, !isBusy, leavers.isEmpty else { return }
            peek = restPeek
        }
    }
    @ObservationIgnored private let session: SwipeSession
    @ObservationIgnored private var pastThreshold = false
    /// Bumped whenever the front card starts a new animation or is grabbed, so a stale
    /// completion handler never touches the card that replaced it.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var leaverSerial = 0
    @ObservationIgnored private var isReturning = false
    @ObservationIgnored private var pendingAction: DecisionAction?
    @ObservationIgnored private var pendingTask: Task<Void, Never>?

    private static let maxLeavers = 3
    /// Far longer than any fly-off (about 0.3 s), short enough that a ghost card is not noticed.
    private static let leaverWatchdog = Duration.milliseconds(1500)

    init(session: SwipeSession) {
        self.session = session
    }

    private var restPeek: CGFloat { reduceMotion ? 1 : 0 }

    // MARK: Drag

    func dragChanged(_ translation: CGSize) {
        guard !isBusy, session.current != nil else { return }
        if !isDragging {
            generation += 1
            isDragging = true
        }
        var dy = translation.height
        if dy > 0 {
            // Rubber band: starts at the old 0.3 slope, never passes 40 pt.
            dy = 40 * (1 - exp(-dy / 133))
        } else {
            dy = max(dy, -cardSize.height * 0.5)
        }
        offset = CGSize(width: translation.width, height: dy)
        rotation = reduceMotion ? 0 : min(15, max(-15, translation.width / 20))
        let (kind, p) = Self.classify(translation)
        stampKind = p > 0 ? kind : nil
        stampProgress = p
        peek = reduceMotion ? 1 : p

        let past = p >= 1
        if past != pastThreshold {
            pastThreshold = past
            thresholdTick += 1
        }
    }

    func dragEnded(translation: CGSize, predictedEnd: CGSize, velocity: CGSize) {
        guard !isBusy, isDragging else { return }
        isDragging = false
        pastThreshold = false
        if let action = Self.decision(translation: translation, predictedEnd: predictedEnd, cardSize: cardSize) {
            flyOff(action, velocity: velocity, predictedEnd: predictedEnd, fromDrag: true)
        } else {
            snapBack()
        }
    }

    /// The gesture was cancelled by the system (no `onEnded`): put the card back.
    func cancelDragIfNeeded() {
        guard isDragging else { return }
        isDragging = false
        pastThreshold = false
        snapBack()
    }

    /// The commit rule. The side is the side the card is on; a flick that opposes it cancels.
    static func decision(translation: CGSize, predictedEnd: CGSize, cardSize: CGSize) -> DecisionAction? {
        let upDominant = abs(translation.height) > abs(translation.width) && translation.height < 0
        if upDominant {
            let p = min(1, -translation.height / 120)
            return (p >= 1 || -predictedEnd.height > cardSize.height * 0.30) ? .favorite : nil
        }
        let p = min(1, abs(translation.width) / 110)
        let predictedSide: CGFloat = predictedEnd.width > 0 ? 1 : (predictedEnd.width < 0 ? -1 : 0)
        let side: CGFloat = translation.width != 0 ? (translation.width > 0 ? 1 : -1) : predictedSide
        guard side != 0 else { return nil }
        if p >= 1 { return side > 0 ? .keep : .trash }
        if abs(predictedEnd.width) > cardSize.width * 0.35, predictedSide == side {
            return side > 0 ? .keep : .trash
        }
        return nil
    }

    private static func classify(_ t: CGSize) -> (DecisionAction, Double) {
        if abs(t.height) > abs(t.width), t.height < 0 {
            return (.favorite, min(1, max(0, Double(-t.height / 120))))
        }
        let p = min(1, max(0, Double(abs(t.width) / 110)))
        return (t.width >= 0 ? .keep : .trash, p)
    }

    // MARK: Commit

    /// Button, VoiceOver action or gesture commit.
    func perform(_ action: DecisionAction) {
        guard !isDragging else { return }
        // A tap during the previous tap's head start launches that card first; a tap during an
        // undo return puts the returning card at rest. Taps are never dropped.
        launchPending()
        finishReturn()
        guard session.current != nil else { return }
        isBusy = true
        pendingAction = action
        // The stamp reaches full opacity before the card leaves.
        withAnimation(.easeOut(duration: 0.08)) {
            stampKind = action
            stampProgress = 1
        }
        pendingTask = Task { [self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            launchPending()
        }
    }

    private func launchPending() {
        guard let action = pendingAction else { return }
        pendingTask?.cancel()
        pendingTask = nil
        pendingAction = nil
        isBusy = false
        flyOff(action, velocity: .zero, predictedEnd: .zero, fromDrag: false)
    }

    private func flyOff(_ action: DecisionAction, velocity: CGSize, predictedEnd: CGSize, fromDrag: Bool) {
        guard let item = session.current else { reset(); return }
        isDragging = false
        generation += 1
        while leavers.count >= Self.maxLeavers { dropLeaver(id: leavers[0].id) }

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
        let dx = target.width - offset.width
        let dy = target.height - offset.height
        let distance = max(1, hypot(dx, dy))
        // Velocity along the exit path only; a release moving away from the exit adds nothing.
        let along = max(0, (velocity.width * dx + velocity.height * dy) / distance)

        emitHaptic(action)
        announce(action)

        leaverSerial += 1
        let serial = leaverSerial
        let id = item.id

        // One transaction for the whole hand-over: the card that was next is now the front card
        // and rises into place while the decided card leaves on its own pose.
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.18)
            : .interpolatingSpring(mass: 1, stiffness: 170, damping: 24, initialVelocity: Double(along / distance))
        withAnimation(animation) {
            switch action {
            case .keep: session.keep()
            case .trash: session.trash()
            case .favorite: session.favorite()
            }
            leavers.append(Leaver(
                item: item, generation: serial,
                offset: reduceMotion ? offset : target,
                rotation: reduceMotion ? rotation : endRotation,
                stampKind: action, stampProgress: 1,
                opacity: reduceMotion ? 0 : 1
            ))
            offset = .zero
            rotation = 0
            peek = restPeek
            stampKind = nil
            stampProgress = 0
            movingOpacity = 1
        } completion: { [self] in
            dropLeaver(id: id, generation: serial)
        }
        // Watchdog: the leaver is normally removed by the completion above. If that completion is
        // ever lost, a ghost card would stay on screen and the empty state would never show, so
        // remove it by (id, generation) after a while. A no-op when the completion already ran.
        Task { [self] in
            try? await Task.sleep(for: Self.leaverWatchdog)
            dropLeaver(id: id, generation: serial)
        }
    }

    private func snapBack() {
        generation += 1
        let g = generation
        let animation: Animation = reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.72)
        withAnimation(animation) {
            offset = .zero
            rotation = 0
            peek = restPeek
            stampProgress = 0
        } completion: { [self] in
            guard g == generation else { return }
            if !isDragging { stampKind = nil }
        }
    }

    // MARK: Undo

    func undo() {
        guard !isDragging else { return }
        launchPending()
        guard session.canUndo, let decision = session.history.last else { return }
        finishReturn()
        // Only the card being restored is fast-forwarded; other cards keep flying.
        dropLeaver(id: decision.item.id)
        isBusy = true
        isReturning = true
        generation += 1
        let g = generation
        let action = decision.action
        let sign: CGFloat = action == .keep ? 1 : -1
        emit(.undo)
        AccessibilityNotification.Announcement(String(localized: "swipe.announce.undone", defaultValue: "Undone.")).post()

        // The restored card starts at the transform it left with, stamp visible, then returns.
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            session.undo()
            stampKind = action
            if reduceMotion {
                offset = .zero; rotation = 0; peek = 1; stampProgress = 0; movingOpacity = 0
            } else if action == .favorite {
                offset = CGSize(width: 0, height: -(cardSize.height * 1.2)); rotation = 0; peek = 1; stampProgress = 1
            } else {
                offset = CGSize(width: sign * cardSize.width * 1.5, height: 0); rotation = Double(sign) * 22; peek = 1; stampProgress = 1
            }
        }
        Task { [self] in
            // One frame so the start transform is rendered before the spring runs.
            try? await Task.sleep(for: .milliseconds(24))
            guard g == generation else { return }
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.18)) { movingOpacity = 1 } completion: { [self] in
                    if g == generation { reset() }
                }
            } else {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                    offset = .zero; rotation = 0; peek = 0; stampProgress = 0
                } completion: { [self] in
                    if g == generation { reset() }
                }
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
            case .keep: offset = CGSize(width: 40, height: -6); rotation = 2.0
            case .trash: offset = CGSize(width: -40, height: -6); rotation = -2.0
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

    /// Stamp of a card by id: the front card's live stamp, or a leaver's own.
    func stamp(leaving id: String?) -> (kind: DecisionAction?, progress: Double) {
        if let id, let leaver = leavers.first(where: { $0.id == id }) {
            return (leaver.stampKind, leaver.stampProgress)
        }
        return (stampKind, stampProgress)
    }

    /// Removes a leaver without animation. With a generation, only if it is still that flight.
    private func dropLeaver(id: String, generation: Int? = nil) {
        guard let index = leavers.firstIndex(where: { $0.id == id && (generation == nil || $0.generation == generation) }) else { return }
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { _ = leavers.remove(at: index) }
    }

    /// An undo return in flight is put at rest at once.
    private func finishReturn() {
        guard isReturning else { return }
        generation += 1
        reset()
    }

    private func reset() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) {
            offset = .zero
            rotation = 0
            peek = restPeek
            stampKind = nil
            stampProgress = 0
            movingOpacity = 1
            isBusy = false
            isDragging = false
            isReturning = false
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
