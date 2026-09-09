import SwiftUI

// MARK: - Color Hex Initializer
public extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - App Theme Model
public struct AppTheme: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let tagline: String
    public let category: String

    // Surfaces & Boundaries
    public let background: Color
    public let surface: Color
    public let surfaceHover: Color
    public let border: Color
    public let borderActive: Color

    // Monospace Typography Colors
    public let textPrimary: Color
    public let textSecondary: Color
    public let textMuted: Color

    // Quota Accents
    public let green: Color
    public let amber: Color
    public let red: Color
    public let cyan: Color
    public let purple: Color
    public let accent: Color

    // Preview Swatches (Hex strings for UI display)
    public let bgHex: String
    public let surfaceHex: String
    public let accentHex: String
    public let secondaryHex: String

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Theme Registry
public enum ThemeRegistry {
    // Core Themes
    public static let t3Default = AppTheme(
        id: "t3-default",
        name: "Emerald",
        tagline: "Signature Graphite & Neon Emerald",
        category: "Core Themes",
        background: Color(hex: "#0d0d0f"),
        surface: Color(hex: "#17171c"),
        surfaceHover: Color(hex: "#202026"),
        border: Color.white.opacity(0.08),
        borderActive: Color.white.opacity(0.22),
        textPrimary: Color(hex: "#f1f3f7"),
        textSecondary: Color(hex: "#9ea1ab"),
        textMuted: Color(hex: "#6b6e78"),
        green: Color(hex: "#00e599"),
        amber: Color(hex: "#fa9e2e"),
        red: Color(hex: "#f54752"),
        cyan: Color(hex: "#38bdf8"),
        purple: Color(hex: "#a877fa"),
        accent: Color(hex: "#00e599"),
        bgHex: "#0d0d0f",
        surfaceHex: "#17171c",
        accentHex: "#00e599",
        secondaryHex: "#38bdf8"
    )

    public static let t3Ocean = AppTheme(
        id: "t3-ocean",
        name: "Ocean",
        tagline: "Deep Nautical Navy & Tech Cyan",
        category: "Core Themes",
        background: Color(hex: "#0a0f18"),
        surface: Color(hex: "#111a29"),
        surfaceHover: Color(hex: "#18253a"),
        border: Color(hex: "#38bdf8").opacity(0.12),
        borderActive: Color(hex: "#38bdf8").opacity(0.32),
        textPrimary: Color(hex: "#e2e8f0"),
        textSecondary: Color(hex: "#94a3b8"),
        textMuted: Color(hex: "#64748b"),
        green: Color(hex: "#38bdf8"),
        amber: Color(hex: "#fbbf24"),
        red: Color(hex: "#f87171"),
        cyan: Color(hex: "#00d8f6"),
        purple: Color(hex: "#818cf8"),
        accent: Color(hex: "#38bdf8"),
        bgHex: "#0a0f18",
        surfaceHex: "#111a29",
        accentHex: "#38bdf8",
        secondaryHex: "#60a5fa"
    )

    public static let t3Grove = AppTheme(
        id: "t3-grove",
        name: "Grove",
        tagline: "Forest Slate & Mint Emerald",
        category: "Core Themes",
        background: Color(hex: "#09120e"),
        surface: Color(hex: "#101e17"),
        surfaceHover: Color(hex: "#172b21"),
        border: Color(hex: "#34d399").opacity(0.12),
        borderActive: Color(hex: "#34d399").opacity(0.32),
        textPrimary: Color(hex: "#e6f4ea"),
        textSecondary: Color(hex: "#9ecbb3"),
        textMuted: Color(hex: "#5d8570"),
        green: Color(hex: "#10b981"),
        amber: Color(hex: "#f59e0b"),
        red: Color(hex: "#f43f5e"),
        cyan: Color(hex: "#2dd4bf"),
        purple: Color(hex: "#a78bfa"),
        accent: Color(hex: "#10b981"),
        bgHex: "#09120e",
        surfaceHex: "#101e17",
        accentHex: "#10b981",
        secondaryHex: "#34d399"
    )

    public static let t3Iris = AppTheme(
        id: "t3-iris",
        name: "Iris",
        tagline: "Void Violet & Neon Lavender",
        category: "Core Themes",
        background: Color(hex: "#0e0d18"),
        surface: Color(hex: "#181528"),
        surfaceHover: Color(hex: "#231f3b"),
        border: Color(hex: "#a855f7").opacity(0.14),
        borderActive: Color(hex: "#a855f7").opacity(0.35),
        textPrimary: Color(hex: "#f5f0ff"),
        textSecondary: Color(hex: "#c4b5fd"),
        textMuted: Color(hex: "#7e6e9f"),
        green: Color(hex: "#a855f7"),
        amber: Color(hex: "#f59e0b"),
        red: Color(hex: "#f43f5e"),
        cyan: Color(hex: "#38bdf8"),
        purple: Color(hex: "#c084fc"),
        accent: Color(hex: "#a855f7"),
        bgHex: "#0e0d18",
        surfaceHex: "#181528",
        accentHex: "#a855f7",
        secondaryHex: "#c084fc"
    )

    public static let t3Ember = AppTheme(
        id: "t3-ember",
        name: "Ember",
        tagline: "Warm Charcoal & Glowing Amber",
        category: "Core Themes",
        background: Color(hex: "#130f0d"),
        surface: Color(hex: "#1f1814"),
        surfaceHover: Color(hex: "#2d231d"),
        border: Color(hex: "#f97316").opacity(0.14),
        borderActive: Color(hex: "#f97316").opacity(0.35),
        textPrimary: Color(hex: "#fff7ed"),
        textSecondary: Color(hex: "#fdba74"),
        textMuted: Color(hex: "#8c6b54"),
        green: Color(hex: "#f97316"),
        amber: Color(hex: "#fbbf24"),
        red: Color(hex: "#ef4444"),
        cyan: Color(hex: "#fb923c"),
        purple: Color(hex: "#f43f5e"),
        accent: Color(hex: "#f97316"),
        bgHex: "#130f0d",
        surfaceHex: "#1f1814",
        accentHex: "#f97316",
        secondaryHex: "#fbbf24"
    )

    // Popular Developer Themes
    public static let tokyoNight = AppTheme(
        id: "tokyo-night",
        name: "Tokyo Night",
        tagline: "Shinjuku Indigo & Synthwave Neon",
        category: "Developer Classics",
        background: Color(hex: "#1a1b26"),
        surface: Color(hex: "#24283b"),
        surfaceHover: Color(hex: "#2f354f"),
        border: Color(hex: "#7aa2f7").opacity(0.15),
        borderActive: Color(hex: "#7aa2f7").opacity(0.4),
        textPrimary: Color(hex: "#c0caf5"),
        textSecondary: Color(hex: "#9aa5ce"),
        textMuted: Color(hex: "#565f89"),
        green: Color(hex: "#9ece6a"),
        amber: Color(hex: "#e0af68"),
        red: Color(hex: "#f7768e"),
        cyan: Color(hex: "#7dcfff"),
        purple: Color(hex: "#bb9af7"),
        accent: Color(hex: "#7aa2f7"),
        bgHex: "#1a1b26",
        surfaceHex: "#24283b",
        accentHex: "#7aa2f7",
        secondaryHex: "#7dcfff"
    )

    public static let cyberpunk = AppTheme(
        id: "cyberpunk",
        name: "Matrix Cyber",
        tagline: "Deep Void & Toxic Phosphor Green",
        category: "Developer Classics",
        background: Color(hex: "#040806"),
        surface: Color(hex: "#0c150f"),
        surfaceHover: Color(hex: "#122118"),
        border: Color(hex: "#22c55e").opacity(0.18),
        borderActive: Color(hex: "#22c55e").opacity(0.45),
        textPrimary: Color(hex: "#dcfce7"),
        textSecondary: Color(hex: "#86efac"),
        textMuted: Color(hex: "#22543d"),
        green: Color(hex: "#22c55e"),
        amber: Color(hex: "#eab308"),
        red: Color(hex: "#ef4444"),
        cyan: Color(hex: "#06b6d4"),
        purple: Color(hex: "#d946ef"),
        accent: Color(hex: "#22c55e"),
        bgHex: "#040806",
        surfaceHex: "#0c150f",
        accentHex: "#22c55e",
        secondaryHex: "#06b6d4"
    )

    public static let palenight = AppTheme(
        id: "palenight",
        name: "Palenight",
        tagline: "Material Minimalist & Soft Lilac",
        category: "Developer Classics",
        background: Color(hex: "#202330"),
        surface: Color(hex: "#292d3e"),
        surfaceHover: Color(hex: "#34394f"),
        border: Color(hex: "#c792ea").opacity(0.14),
        borderActive: Color(hex: "#c792ea").opacity(0.35),
        textPrimary: Color(hex: "#eeffff"),
        textSecondary: Color(hex: "#bfc7d5"),
        textMuted: Color(hex: "#676e95"),
        green: Color(hex: "#c3e88d"),
        amber: Color(hex: "#ffcb6b"),
        red: Color(hex: "#ff5370"),
        cyan: Color(hex: "#89ddff"),
        purple: Color(hex: "#c792ea"),
        accent: Color(hex: "#82aaff"),
        bgHex: "#202330",
        surfaceHex: "#292d3e",
        accentHex: "#82aaff",
        secondaryHex: "#c792ea"
    )

    public static let dracula = AppTheme(
        id: "dracula",
        name: "Dracula",
        tagline: "Gothic Midnight & Neon Pink",
        category: "Developer Classics",
        background: Color(hex: "#21222c"),
        surface: Color(hex: "#282a36"),
        surfaceHover: Color(hex: "#343746"),
        border: Color(hex: "#bd93f9").opacity(0.15),
        borderActive: Color(hex: "#bd93f9").opacity(0.4),
        textPrimary: Color(hex: "#f8f8f2"),
        textSecondary: Color(hex: "#bfbfbf"),
        textMuted: Color(hex: "#6272a4"),
        green: Color(hex: "#50fa7b"),
        amber: Color(hex: "#f1fa8c"),
        red: Color(hex: "#ff5555"),
        cyan: Color(hex: "#8be9fd"),
        purple: Color(hex: "#bd93f9"),
        accent: Color(hex: "#ff79c6"),
        bgHex: "#21222c",
        surfaceHex: "#282a36",
        accentHex: "#ff79c6",
        secondaryHex: "#bd93f9"
    )

    public static let solarized = AppTheme(
        id: "solarized",
        name: "Solarized Dark",
        tagline: "Classic Teal & Precision Solar",
        category: "Developer Classics",
        background: Color(hex: "#00212b"),
        surface: Color(hex: "#073642"),
        surfaceHover: Color(hex: "#0e4554"),
        border: Color(hex: "#2aa198").opacity(0.18),
        borderActive: Color(hex: "#2aa198").opacity(0.42),
        textPrimary: Color(hex: "#fdf6e3"),
        textSecondary: Color(hex: "#93a1a1"),
        textMuted: Color(hex: "#586e75"),
        green: Color(hex: "#859900"),
        amber: Color(hex: "#b58900"),
        red: Color(hex: "#dc322f"),
        cyan: Color(hex: "#2aa198"),
        purple: Color(hex: "#6c71c4"),
        accent: Color(hex: "#2aa198"),
        bgHex: "#00212b",
        surfaceHex: "#073642",
        accentHex: "#2aa198",
        secondaryHex: "#268bd2"
    )

    public static let allThemes: [AppTheme] = [
        t3Default,
        t3Ocean,
        t3Grove,
        t3Iris,
        t3Ember,
        tokyoNight,
        cyberpunk,
        palenight,
        dracula,
        solarized
    ]

    public static func theme(for id: String) -> AppTheme {
        let clean = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch clean {
        case "emerald", "default", "t3-default":
            return t3Default
        case "ocean", "t3-ocean":
            return t3Ocean
        case "grove", "t3-grove":
            return t3Grove
        case "iris", "t3-iris":
            return t3Iris
        case "ember", "t3-ember":
            return t3Ember
        case "tokyo", "tokyo-night":
            return tokyoNight
        case "cyber", "cyberpunk", "matrix":
            return cyberpunk
        case "pale", "palenight":
            return palenight
        case "dracula":
            return dracula
        case "solar", "solarized":
            return solarized
        default:
            return allThemes.first { $0.id == clean } ?? t3Default
        }
    }
}
