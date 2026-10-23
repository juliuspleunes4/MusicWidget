import SwiftUI
import AppIntents

// MARK: - Options (these are also the widget's settings)

enum ThemeOption: String, AppEnum, CaseIterable {
    case system, light, dark, ultraDark, midnight, ocean, forest, sunset, rose, lavender

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Theme"
    static var caseDisplayRepresentations: [ThemeOption: DisplayRepresentation] = [
        .system: "Automatic (follows macOS)",
        .light: "Light",
        .dark: "Dark",
        .ultraDark: "Ultra Dark (pure black)",
        .midnight: "Midnight",
        .ocean: "Ocean",
        .forest: "Forest",
        .sunset: "Sunset",
        .rose: "Rose",
        .lavender: "Lavender",
    ]

    var label: String {
        switch self {
        case .system: return "Automatic"
        case .ultraDark: return "Ultra Dark"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

enum AccentOption: String, AppEnum, CaseIterable {
    case themeDefault, spotifyGreen, white, red, orange, yellow, blue, purple, pink

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Accent Color"
    static var caseDisplayRepresentations: [AccentOption: DisplayRepresentation] = [
        .themeDefault: "Theme default",
        .spotifyGreen: "Spotify green",
        .white: "White",
        .red: "Red",
        .orange: "Orange",
        .yellow: "Yellow",
        .blue: "Blue",
        .purple: "Purple",
        .pink: "Pink",
    ]

    var color: Color? {
        switch self {
        case .themeDefault: return nil
        case .spotifyGreen: return Color(red: 0.12, green: 0.84, blue: 0.38)
        case .white: return .white
        case .red: return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .orange: return Color(red: 1.0, green: 0.60, blue: 0.20)
        case .yellow: return Color(red: 1.0, green: 0.84, blue: 0.25)
        case .blue: return Color(red: 0.35, green: 0.62, blue: 1.0)
        case .purple: return Color(red: 0.70, green: 0.50, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.45, blue: 0.72)
        }
    }
}

enum CornerOption: String, AppEnum, CaseIterable {
    case sharp, soft, round

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Artwork Corners"
    static var caseDisplayRepresentations: [CornerOption: DisplayRepresentation] = [
        .sharp: "Sharp", .soft: "Soft", .round: "Round",
    ]

    var scale: CGFloat {
        switch self {
        case .sharp: return 0.1
        case .soft: return 1
        case .round: return 1.8
        }
    }
}

/// Everything a widget needs to know about how it should look.
struct WidgetStyle {
    var theme: ThemeOption = .system
    var accent: AccentOption = .themeDefault
    var corners: CornerOption = .soft
    var artworkBackdrop = false
}

// MARK: - Resolved colors

struct ThemePalette {
    let colors: [Color]      // one = solid background, two or more = diagonal gradient
    let text: Color
    let secondary: Color
    let accent: Color

    @ViewBuilder var backgroundView: some View {
        if colors.count > 1 {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            colors[0]
        }
    }

    /// Text colors used when artwork is drawn behind the content.
    var onDark: ThemePalette {
        ThemePalette(colors: colors, text: .white, secondary: .white.opacity(0.7), accent: accent)
    }

    static func make(theme: ThemeOption, accent: AccentOption) -> ThemePalette {
        let base = base(for: theme)
        guard let override = accent.color else { return base }
        return ThemePalette(colors: base.colors, text: base.text, secondary: base.secondary, accent: override)
    }

    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    private static func base(for theme: ThemeOption) -> ThemePalette {
        let green = hex(0x1ED760)
        switch theme {
        case .system:
            return .init(colors: [Color(nsColor: .windowBackgroundColor)], text: .primary, secondary: .secondary, accent: green)
        case .light:
            return .init(colors: [hex(0xF7F7F8)], text: hex(0x16161A), secondary: hex(0x16161A).opacity(0.55), accent: hex(0x15A84A))
        case .dark:
            return .init(colors: [hex(0x1C1C1E)], text: .white, secondary: .white.opacity(0.6), accent: green)
        case .ultraDark:
            return .init(colors: [.black], text: .white, secondary: .white.opacity(0.5), accent: .white)
        case .midnight:
            return .init(colors: [hex(0x0B1026), hex(0x1B2A5C)], text: .white, secondary: .white.opacity(0.65), accent: hex(0x7AA2FF))
        case .ocean:
            return .init(colors: [hex(0x023E58), hex(0x0A8FA6)], text: .white, secondary: .white.opacity(0.7), accent: hex(0x7FF0E0))
        case .forest:
            return .init(colors: [hex(0x0F2A1D), hex(0x1F5B3A)], text: .white, secondary: .white.opacity(0.65), accent: hex(0x6BE39A))
        case .sunset:
            return .init(colors: [hex(0xFF7A45), hex(0xC2185B)], text: .white, secondary: .white.opacity(0.75), accent: hex(0xFFE1A8))
        case .rose:
            return .init(colors: [hex(0xFBE3EA), hex(0xF4B6C8)], text: hex(0x4A1626), secondary: hex(0x4A1626).opacity(0.6), accent: hex(0xD6336C))
        case .lavender:
            return .init(colors: [hex(0x2B1B4F), hex(0x6A4BB8)], text: .white, secondary: .white.opacity(0.7), accent: hex(0xC9B2FF))
        }
    }
}
