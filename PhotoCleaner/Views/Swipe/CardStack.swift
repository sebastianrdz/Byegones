import SwiftUI

/// The front card, the next one peeking behind it, and any cards still flying out on top.
/// A decided card keeps flying on its own pose, so the front card is draggable at once.
struct CardStack: View {
    let session: SwipeSession
    let controller: CardController
    let store: CardImageStore
    @Binding var isMuted: Bool

    @GestureState private var gestureActive = false

    enum Role: Equatable { case next, front, leaving }

    private struct Layer: Identifiable {
        let item: MediaItem
        let role: Role
        var id: String { item.id }
    }

    private var layers: [Layer] {
        var result: [Layer] = []
        if session.queue.count > 1 { result.append(Layer(item: session.queue[1], role: .next)) }
        if let current = session.current { result.append(Layer(item: current, role: .front)) }
        for leaver in controller.leavers where !result.contains(where: { $0.id == leaver.id }) {
            result.append(Layer(item: leaver.item, role: .leaving))
        }
        return result
    }

    var body: some View {
        ZStack {
            ForEach(layers) { layer in
                card(layer)
            }
        }
        // A system-cancelled drag never reports `onEnded`; without this the card would stay put.
        .onChange(of: gestureActive) { _, active in
            if !active { controller.cancelDragIfNeeded() }
        }
    }

    private func card(_ layer: Layer) -> some View {
        let role = layer.role
        let leaver = controller.leavers.first { $0.id == layer.id }
        let peek = controller.peek
        let isFront = role == .front
        return CardView(
            item: layer.item,
            isTop: role != .next,
            isLeaving: role == .leaving,
            session: session,
            controller: controller,
            store: store,
            isMuted: $isMuted
        )
        .scaleEffect(role == .next ? 0.94 + 0.06 * peek : 1)
        .offset(
            x: isFront ? controller.offset.width : (leaver?.offset.width ?? 0),
            y: isFront ? controller.offset.height : (leaver?.offset.height ?? 14 * (1 - peek))
        )
        .rotationEffect(.degrees(isFront ? controller.rotation : (leaver?.rotation ?? 0)))
        .opacity(isFront ? controller.movingOpacity : (leaver?.opacity ?? 1))
        .zIndex(role == .next ? 0 : (isFront ? 1 : 2))
        .allowsHitTesting(isFront && !controller.isBusy)
        .gesture(dragGesture, including: isFront ? .all : .none)
        .transition(.identity)
        .accessibilityHidden(!isFront)
        .accessibilityElement(children: isFront ? .ignore : .contain)
        .accessibilityLabel(isFront ? Text(Strings.cardA11y(item: layer.item)) : Text(verbatim: ""))
        .accessibilityHint(Text("swipe.card.a11y.actions"))
        .accessibilityIdentifier(isFront ? "swipe.card" : (role == .next ? "swipe.card.next" : "swipe.card.leaving"))
        .accessibilityActions {
            Button("swipe.button.keep.label") { controller.perform(.keep) }
            Button("swipe.button.delete.label") { controller.perform(.trash) }
            Button("swipe.button.favorite.label") { controller.perform(.favorite) }
            if session.canUndo { Button("swipe.button.undo.label") { controller.undo() } }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($gestureActive) { _, state, _ in state = true }
            .onChanged { controller.dragChanged($0.translation) }
            .onEnded {
                controller.dragEnded(
                    translation: $0.translation,
                    predictedEnd: $0.predictedEndTranslation,
                    velocity: $0.velocity
                )
            }
    }
}
