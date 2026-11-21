import SwiftUI

/// KEEP / DELETE / FAVORITE stamp laid over the front card. Decorative for VoiceOver.
struct StampView: View {
    let action: DecisionAction

    var body: some View {
        HStack(spacing: Space.xs) {
            if action == .favorite {
                Image(systemName: "star.fill")
            }
            Text(action.stampKey)
                .textCase(.uppercase)
                .tracking(1.5)
                .multilineTextAlignment(.center)
        }
        .font(.rounded(.title2, weight: .heavy))
        .foregroundStyle(Color.onFill)
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
        .background(action.fillColor, in: RoundedRectangle(cornerRadius: Radius.stamp, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.stamp, style: .continuous)
                .strokeBorder(action.fillColor, lineWidth: 4)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .rotationEffect(.degrees(rotation))
        // The stamp is a graphic over the photo, not reading text: keep it from outgrowing the card.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHidden(true)
    }

    private var rotation: Double {
        switch action {
        case .keep: -12
        case .trash: 12
        case .favorite: 0
        }
    }
}
