import SwiftUI

/// At most two cards: the moving front card and the next one peeking behind it.
struct CardStack: View {
    let session: SwipeSession
    let controller: CardController
    let store: CardImageStore
    @Binding var isMuted: Bool

    private struct Layer: Identifiable {
        let item: MediaItem
        let isTop: Bool
        var id: String { item.id }
    }

    private var layers: [Layer] {
        let top = controller.departing ?? session.current
        let below: MediaItem? = controller.departing != nil
            ? session.current
            : (session.queue.count > 1 ? session.queue[1] : nil)
        return [below.map { Layer(item: $0, isTop: false) }, top.map { Layer(item: $0, isTop: true) }].compactMap { $0 }
    }

    var body: some View {
        ZStack {
            ForEach(layers) { layer in
                card(layer)
            }
        }
    }

    private func card(_ layer: Layer) -> some View {
        let isTop = layer.isTop
        let peek = controller.peek
        return CardView(
            item: layer.item,
            isTop: isTop,
            session: session,
            controller: controller,
            store: store,
            isMuted: $isMuted
        )
        .scaleEffect(isTop ? 1 : 0.94 + 0.06 * peek)
        .offset(
            x: isTop ? controller.offset.width : 0,
            y: isTop ? controller.offset.height : 14 * (1 - peek)
        )
        .rotationEffect(.degrees(isTop ? controller.rotation : 0))
        .opacity(isTop ? controller.movingOpacity : 1)
        .zIndex(isTop ? 1 : 0)
        .allowsHitTesting(isTop && !controller.isBusy)
        .gesture(dragGesture, including: isTop ? .all : .none)
        .accessibilityHidden(!isTop)
        .accessibilityElement(children: isTop ? .ignore : .contain)
        .accessibilityLabel(isTop ? Text(Strings.cardA11y(item: layer.item)) : Text(verbatim: ""))
        .accessibilityHint(Text("swipe.card.a11y.actions"))
        .accessibilityActions {
            Button("swipe.button.keep.label") { controller.perform(.keep) }
            Button("swipe.button.delete.label") { controller.perform(.trash) }
            Button("swipe.button.favorite.label") { controller.perform(.favorite) }
            if session.canUndo { Button("swipe.button.undo.label") { controller.undo() } }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
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
