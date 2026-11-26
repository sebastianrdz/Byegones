import Foundation

/// Localized strings that take arguments. Keys and variants live in Localizable.xcstrings;
/// the `defaultValue` argument order must match the format specifiers there.
enum Strings {
    static func counter(_ n: Int) -> String {
        String(localized: "swipe.counter", defaultValue: "\(n) left")
    }

    static func counterA11y(_ n: Int) -> String {
        String(localized: "swipe.counter.a11y", defaultValue: "\(n) items left to review")
    }

    static func trashPill(count: Int, bytes: Int64?) -> String {
        if let bytes {
            let size = ByteFormat.string(bytes)
            return String(localized: "swipe.trash.pill", defaultValue: "\(count) · \(size)")
        }
        return String(localized: "swipe.trash.pill.nosize", defaultValue: "\(count) items")
    }

    static func trashPillA11y(count: Int, bytes: Int64?) -> String {
        guard let bytes else {
            return String(localized: "swipe.trash.pill.nosize", defaultValue: "\(count) items")
        }
        let size = ByteFormat.string(bytes)
        return String(localized: "swipe.trash.pill.a11y", defaultValue: "Trash pile, \(count) items, \(size). Opens review.")
    }

    static func trashSummary(count: Int, bytes: Int64?) -> String {
        if let bytes {
            let size = ByteFormat.string(bytes)
            return String(localized: "trash.summary", defaultValue: "\(count) items · \(size)")
        }
        return String(localized: "trash.summary.nosize", defaultValue: "\(count) items")
    }

    static func trashedAnnouncement(count: Int) -> String {
        String(localized: "swipe.announce.trashed", defaultValue: "Moved to the trash pile. \(count) items in the pile.")
    }

    static func deleteButton(count: Int) -> String {
        String(localized: "trash.delete.button", defaultValue: "Delete \(count) items")
    }

    static func cardA11y(item: MediaItem) -> String {
        let date = item.creationDate?.formatted(date: .long, time: .omitted) ?? ""
        var label: String
        if item.kind == .video {
            let duration = DurationFormat.string(item.duration)
            label = String(localized: "swipe.card.a11y.video", defaultValue: "Video, \(date), \(duration)")
        } else {
            label = String(localized: "swipe.card.a11y.photo", defaultValue: "Photo, \(date)")
        }
        if let size = item.byteSize {
            let formatted = ByteFormat.string(size)
            label += ". " + String(localized: "swipe.meta.size.a11y", defaultValue: "Size \(formatted)")
        }
        if item.isFavorite {
            label += ". " + String(localized: "swipe.meta.favorite.badge.a11y", defaultValue: "Already a favorite")
        }
        return label
    }

    static func celebrationTitle(bytes: Int64) -> String {
        let size = ByteFormat.string(bytes)
        return String(localized: "celebration.title", defaultValue: "You cleared \(size)!")
    }

    static func celebrationTitleNoSize(count: Int) -> String {
        String(localized: "celebration.title.nosize", defaultValue: "\(count) items cleared!")
    }

    static func lifetime(bytes: Int64) -> String {
        let size = ByteFormat.string(bytes)
        return String(localized: "celebration.lifetime", defaultValue: "Total cleared with Byegones: \(size)")
    }

    static func version(_ marketing: String, _ build: String) -> String {
        String(localized: "settings.version", defaultValue: "Version \(marketing) (\(build))")
    }

    static func pageIndicator(_ page: Int, of total: Int) -> String {
        String(localized: "onboarding.pageindicator.a11y", defaultValue: "Page \(page) of \(total)")
    }
}
