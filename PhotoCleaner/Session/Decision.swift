import Foundation

nonisolated enum DecisionAction: Sendable, Equatable {
    case keep
    case trash
    case favorite
}

nonisolated struct Decision: Sendable, Equatable {
    let item: MediaItem
    let action: DecisionAction
    /// Favorite state in Photos before this decision, restored on undo.
    let wasFavorite: Bool
}

nonisolated enum CommitOutcome: Sendable {
    case deleted(count: Int, bytes: Int64)
    case nothingToDelete
    /// User dismissed the system popup. The pile is unchanged.
    case cancelled
    /// The pile is unchanged.
    case failed(any Error)
}
