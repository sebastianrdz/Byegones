import SwiftUI

/// "All caught up" and "No photos yet", with the single primary action each state needs.
struct EmptyStateView: View {
    let session: SwipeSession
    let onReviewTrash: () -> Void
    let onOpenSettings: () -> Void

    private var isLibraryEmpty: Bool { session.totalCount == 0 && session.pendingTrash.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.m) {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityHidden(true)
                Text(isLibraryEmpty ? "empty.library.title" : "empty.done.title")
                    .font(.rounded(.title2, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                Text(isLibraryEmpty ? "empty.library.body" : "empty.done.body")
                    .font(.body)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                action
                    .padding(.top, Space.m)
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity, minHeight: 360)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var action: some View {
        if session.access == .limited && isLibraryEmpty {
            Button("permission.limited.button") {
                Task {
                    await LimitedLibraryPicker.present()
                    await session.load()
                }
            }
            .buttonStyle(.primary)
            .frame(maxWidth: 320)
        } else if !session.pendingTrash.isEmpty {
            Button("empty.done.review", action: onReviewTrash)
                .buttonStyle(.primary)
                .frame(maxWidth: 320)
        } else if !isLibraryEmpty {
            Button("settings.reset.button", action: onOpenSettings)
                .font(.subheadline)
                .frame(minHeight: 44)
        }
    }
}

/// Two static `surface` cards while the first batch loads. No shimmer.
struct SkeletonCards: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.surface)
                .scaleEffect(0.94)
                .offset(y: 14)
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.surface)
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
        }
        .accessibilityHidden(true)
    }
}
