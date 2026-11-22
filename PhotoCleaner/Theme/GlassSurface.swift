import SwiftUI

/// The one place glass is decided. iOS 26 uses Liquid Glass; iOS 17-25 a material with hairline
/// and shadow; Reduce Transparency / Increased Contrast a solid surface.
private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(Color.hairline, lineWidth: 1))
        } else if #available(iOS 26, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.hairline, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
        }
    }
}

extension View {
    func glassSurface<S: InsettableShape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, interactive: interactive))
    }
}

/// Groups adjacent glass controls so they render and morph as a set on iOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Press feedback shared by every control: scale 0.94 on a short spring (0.1 s ease-out, no
/// overshoot, with Reduce Motion).
///
/// Set `onInteractiveGlass` for a control whose surface is `glassSurface(interactive: true)`: on
/// iOS 26 that glass already scales and bounces under the finger, so adding a second scale here
/// would double the press. Without Liquid Glass (earlier iOS, Reduce Transparency, Increased
/// Contrast) the surface is static and this style supplies the feedback.
struct PressScaleStyle: ButtonStyle {
    var onInteractiveGlass = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var glassPressesItself: Bool {
        guard onInteractiveGlass, !reduceTransparency, contrast != .increased else { return false }
        if #available(iOS 26, *) { return true }
        return false
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !glassPressesItself ? 0.94 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.25, dampingFraction: 0.8),
                value: configuration.isPressed
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .semibold))
            .foregroundStyle(destructive ? Color.onFill : Color.onAccent)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, Space.l)
            .background(destructive ? Color.deleteFill : Color.brand, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryDestructive: PrimaryButtonStyle { PrimaryButtonStyle(destructive: true) }
}
