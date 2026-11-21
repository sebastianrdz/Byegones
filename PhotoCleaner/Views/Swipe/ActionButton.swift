import SwiftUI

/// One of the four glass buttons under the card.
struct ActionButton: View {
    let symbol: String
    let glyphSize: CGFloat
    let diameter: CGFloat
    let color: Color
    let label: LocalizedStringKey
    let hint: LocalizedStringKey
    var isEnabled = true
    /// Screenshot scenes only: draws the control in its just-used state.
    var showsAsUsed = false
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var scale = 1.0

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize * min(scale, 1.4), weight: .semibold))
                .foregroundStyle(showsAsUsed ? Color.onUndoFill : color)
                .frame(width: diameter, height: diameter)
                .background { if showsAsUsed { Circle().fill(Color.undoFill) } }
                .glassSurface(in: Circle(), interactive: true)
                .scaleEffect(showsAsUsed ? 0.94 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
        .accessibilityHint(Text(hint))
    }
}
