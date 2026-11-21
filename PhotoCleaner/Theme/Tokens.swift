import SwiftUI

// Every color is an asset-catalog color set (Any / Dark / High Contrast); no hex in views.
extension Color {
    static let canvas = Color("canvas")
    static let surface = Color("surface")
    static let surfaceRaised = Color("surfaceRaised")
    static let hairline = Color("hairline")
    static let ink = Color("ink")
    static let inkSecondary = Color("inkSecondary")
    static let inkTertiary = Color("inkTertiary")
    static let inkFill = Color("inkFill")
    static let scrim = Color("scrim")
    static let brand = Color("AccentColor")
    static let onAccent = Color("onAccent")

    static let keepGlyph = Color("keepGlyph")
    static let keepFill = Color("keepFill")
    static let deleteGlyph = Color("deleteGlyph")
    static let deleteFill = Color("deleteFill")
    static let favoriteGlyph = Color("favoriteGlyph")
    static let favoriteFill = Color("favoriteFill")
    static let undoGlyph = Color("undoGlyph")
    static let undoFill = Color("undoFill")
    static let onFill = Color("onFill")
    static let onUndoFill = Color("onUndoFill")
}

/// Spacing scale (pt), 4-based.
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 48
}

enum Radius {
    static let card: CGFloat = 36
    static let cell: CGFloat = 14
    static let banner: CGFloat = 20
    static let stamp: CGFloat = 14
}

extension Font {
    /// SF Pro Rounded for display moments and numerals; text styles keep Dynamic Type working.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension DecisionAction {
    var glyphColor: Color {
        switch self {
        case .keep: .keepGlyph
        case .trash: .deleteGlyph
        case .favorite: .favoriteGlyph
        }
    }

    var fillColor: Color {
        switch self {
        case .keep: .keepFill
        case .trash: .deleteFill
        case .favorite: .favoriteFill
        }
    }

    var symbol: String {
        switch self {
        case .keep: "checkmark"
        case .trash: "xmark"
        case .favorite: "star.fill"
        }
    }

    var stampKey: LocalizedStringKey {
        switch self {
        case .keep: "swipe.stamp.keep"
        case .trash: "swipe.stamp.delete"
        case .favorite: "swipe.stamp.favorite"
        }
    }
}

/// Locale-aware byte formatting. Never hard-code units.
enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        return formatter
    }()

    static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}

enum DurationFormat {
    /// m:ss, or h:mm:ss from an hour up.
    static func string(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Illustrative art for the onboarding demo card: an abstract sunset, never a real photo.
enum DemoArt {
    static let skyTop = Color(red: 0.31, green: 0.27, blue: 0.82)
    static let skyMid = Color(red: 0.93, green: 0.45, blue: 0.55)
    static let skyLow = Color(red: 0.99, green: 0.74, blue: 0.40)
    static let hillFar = Color(red: 0.36, green: 0.22, blue: 0.52)
    static let hillNear = Color(red: 0.20, green: 0.13, blue: 0.34)
}
