import SwiftUI

struct CelebrationSummary: Identifiable {
    let id = UUID()
    let count: Int
    let bytes: Int64
    let lifetime: Int64
    let queueIsEmpty: Bool
}

/// The pile, reviewable in one place, committed with one system confirmation.
struct TrashSheet: View {
    let session: SwipeSession
    let onDeleted: (CelebrationSummary) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    private enum Phase { case idle, deleting, cancelled, failed }
    private struct RemovedToast { let item: MediaItem; let index: Int }

    @State private var phase = Phase.idle
    @State private var removing: Set<String> = []
    @State private var toast: RemovedToast?
    @State private var toastTask: Task<Void, Never>?
    @State private var selectionTick = 0
    @State private var successTick = 0
    @State private var errorTick = 0
    @State private var explainerOpen = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    /// At accessibility sizes the footer cannot also hold the explainer: header, caption, grid and
    /// info scroll together, and only the status and the Delete button stay pinned.
    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }

    private var count: Int { session.pendingTrash.count }
    private var bytes: Int64? { session.pendingTrashHasSizes ? session.pendingTrashBytes : nil }

    var body: some View {
        NavigationStack {
            Group {
                if session.pendingTrash.isEmpty && phase != .deleting {
                    emptyState
                } else {
                    grid
                }
            }
            .background(Color.canvas)
            .navigationTitle("trash.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        }
        .presentationDetents(isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
        .sensoryFeedback(.selection, trigger: selectionTick)
        .sensoryFeedback(.success, trigger: successTick)
        .sensoryFeedback(.error, trigger: errorTick)
        .task {
            // Screenshot scene: show the failed-delete state without anyone tapping.
            if ScreenshotMode.current?.scene == .deleteFailed, phase == .idle { await commit() }
        }
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(Strings.trashSummary(count: count, bytes: bytes))
                    .font(.rounded(.title3, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
                Text("trash.hint")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.bottom, Space.s)
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(session.pendingTrash) { item in
                        cell(item)
                    }
                }
                if isAccessibilitySize && !session.pendingTrash.isEmpty {
                    explainer.padding(.top, Space.m)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)
            .padding(.bottom, Space.l)
        }
        .opacity(phase == .deleting ? 0.6 : 1)
        .allowsHitTesting(phase != .deleting)
    }

    private func cell(_ item: MediaItem) -> some View {
        let isRemoving = removing.contains(item.id)
        return Button { remove(item) } label: {
            ThumbnailView(item: item, library: session.library)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.cell, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if item.kind == .video { videoChip(item) }
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.cell, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isRemoving ? 0.8 : 1)
        .opacity(isRemoving ? 0 : 1)
        .accessibilityLabel(Text(Strings.cardA11y(item: item)))
        .accessibilityHint(Text("trash.item.a11y"))
    }

    private func videoChip(_ item: MediaItem) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "video.fill").font(.system(size: 10, weight: .semibold))
            Text(DurationFormat.string(item.duration))
                .font(.rounded(.caption2, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.scrim, in: Capsule())
        .padding(6)
    }

    private var emptyState: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "trash")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityHidden(true)
            Text("trash.empty.title")
                .font(.rounded(.title2, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text("trash.empty.body")
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Space.s) {
            if let toast { toastView(toast) }

            switch phase {
            case .failed:
                Label("error.delete.failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.deleteGlyph)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .cancelled:
                Text("trash.cancelled")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            default:
                EmptyView()
            }

            if !session.pendingTrash.isEmpty || phase == .deleting {
                if !isAccessibilitySize { explainer }

                Button { Task { await commit() } } label: {
                    if phase == .deleting {
                        ProgressView().tint(Color.onFill)
                    } else if phase == .failed {
                        Text("error.retry")
                    } else {
                        Text(Strings.deleteButton(count: count))
                    }
                }
                .buttonStyle(.primaryDestructive)
                .disabled(phase == .deleting)
                .accessibilityHint(Text("trash.delete.hint"))
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.top, Space.m)
        .padding(.bottom, Space.m)
        .background(Color.canvas)
    }

    private var explainer: some View {
        DisclosureGroup(isExpanded: $explainerOpen) {
            Text("trash.explainer.body")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.xs)
        } label: {
            Text("trash.explainer.title")
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
        .tint(Color.inkSecondary)
    }

    private func toastView(_ toast: RemovedToast) -> some View {
        HStack(spacing: Space.m) {
            Text("trash.item.removed")
                .font(.subheadline)
                .foregroundStyle(Color.ink)
            Button("swipe.button.undo.label") {
                toastTask?.cancel()
                withAnimation(.snappy) {
                    session.restoreToTrash(toast.item, at: toast.index)
                    self.toast = nil
                }
                selectionTick += 1
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.brand)
            .frame(minHeight: 44)
            .disabled(session.isCommitting)
        }
        .padding(.horizontal, Space.l)
        .glassSurface(in: Capsule())
        .transition(.opacity)
    }

    // MARK: Actions

    private func remove(_ item: MediaItem) {
        guard !removing.contains(item.id),
              let index = session.pendingTrash.firstIndex(where: { $0.id == item.id }) else { return }
        selectionTick += 1
        withAnimation(.easeOut(duration: 0.2)) { _ = removing.insert(item.id) }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.snappy) {
                session.untrash(item.id)
                removing.remove(item.id)
                toast = RemovedToast(item: item, index: index)
            }
            toastTask?.cancel()
            toastTask = Task {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { toast = nil }
            }
        }
    }

    private func commit() async {
        toastTask?.cancel()
        toast = nil
        phase = .deleting
        switch await session.commitTrash() {
        case .deleted(let deleted, let freed):
            successTick += 1
            onDeleted(CelebrationSummary(
                count: deleted, bytes: freed, lifetime: session.bytesFreed, queueIsEmpty: session.current == nil
            ))
            dismiss()
        case .cancelled:
            phase = .cancelled
        case .failed:
            errorTick += 1
            phase = .failed
        case .nothingToDelete:
            phase = .idle
        }
    }
}

/// Square-cropped thumbnail for the grid.
struct ThumbnailView: View {
    let item: MediaItem
    let library: any PhotoLibraryProviding
    @State private var image: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Color.surfaceRaised
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: item.id) {
                let side = 150 * displayScale
                image = await library.image(for: item.id, targetSize: CGSize(width: side, height: side))
            }
    }
}
