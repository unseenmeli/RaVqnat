import SwiftUI

/// RaVqnat design tokens — "ink on paper with a pink echo".
///
/// Ink-black type and hairline-to-medium ink borders on warm dot-grid paper, an editorial serif
/// for display type, a monospaced face for small labels, and hot pink used sparingly as an
/// "afterimage" (offset echoes behind shapes, selection, the active tab). Every token has a light
/// and a dark value; text/background pairs meet WCAG AA.
enum Theme {
    enum Palette {
        // Paper & ink
        static let canvas = Color(light: 0xF5F4F0, dark: 0x121110)
        static let surface = Color(light: 0xFFFFFF, dark: 0x1B1A18)
        static let surfaceMuted = Color(light: 0xEBE9E3, dark: 0x262422)
        static let ink = Color(light: 0x111111, dark: 0xF3F1EC)
        static let inkSecondary = Color(light: 0x55524D, dark: 0xADA9A2)
        static let inkTertiary = Color(light: 0x85817A, dark: 0x7E7A74)
        static let hairline = Color(light: 0xD9D6CE, dark: 0x3A3734)
        static let dot = Color(light: 0x3C3C43, dark: 0xF3F1EC).opacity(0.13)

        // The pink echo. `accent` is for fills and afterimages; `accentText` passes AA as text on paper.
        static let accent = Color(light: 0xFF2E9A, dark: 0xFF4FAE)
        static let accentText = Color(light: 0xC2126C, dark: 0xFF7AC0)
        static let accentSoft = Color(light: 0xFFE3F1, dark: 0x3A1528)

        // Primary actions are ink with paper text (inverted in dark mode).
        static let brand = ink
        static let onBrand = canvas
        static let brandSoft = surfaceMuted

        // Semantic
        static let trust = ink
        static let trustSoft = surfaceMuted
        static let success = Color(light: 0x1F7A4D, dark: 0x5BC88C)
        static let warning = Color(light: 0x8F5600, dark: 0xF2B04D)
        static let warningSoft = Color(light: 0xF8ECD6, dark: 0x3A2C14)
        static let danger = Color(light: 0xC0262D, dark: 0xFF6B70)
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let screen: CGFloat = 20
    }

    enum Radius {
        /// Near-square corners: editorial, not bubbly.
        static let card: CGFloat = 6
        static let control: CGFloat = 4
        static let small: CGFloat = 3
    }

    enum Stroke {
        static let hairline: CGFloat = 1
        static let regular: CGFloat = 1.5
        static let bold: CGFloat = 2
    }

    /// Offset of the hard "afterimage" shadow behind cards and primary buttons.
    static let echoOffset: CGFloat = 4
}

extension ActivityCategory {
    /// Categories are differentiated by symbol and screentone pattern, not by colour.
    var tint: Color { Theme.Palette.ink }
    var softTint: Color { Theme.Palette.surfaceMuted }

    /// Screentone used in cover art.
    var pattern: HalftonePattern {
        switch self {
        case .music, .arts: .dots
        case .sports, .outdoors: .diagonal
        case .learning, .technology: .grid
        case .food, .games: .gradientDots
        case .other: .dots
        }
    }
}

enum HalftonePattern { case dots, gradientDots, diagonal, grid }

extension Color {
    /// A colour that resolves differently in light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Font {
    /// Editorial serif (New York) for headings; SF Pro stays the reading face.
    static let rvDisplay = Font.system(.largeTitle, design: .serif)
    static let rvTitle = Font.system(.title, design: .serif)
    static let rvTitle3 = Font.system(.title3, design: .serif).weight(.medium)
    static let rvHeadline = Font.system(.title3, design: .serif).weight(.medium)
    /// Monospaced small labels (metadata, tags, buttons).
    static let rvCaption = Font.system(.caption, design: .monospaced).weight(.medium)
    static let rvLabel = Font.system(.footnote, design: .monospaced).weight(.semibold)
    static let rvButton = Font.system(.subheadline, design: .monospaced).weight(.bold)
}

enum Typography {
    /// Georgian has no letter case in everyday script; uppercasing Mkhedruli produces Mtavruli,
    /// which is harder to read, so labels are only uppercased for Latin-script UI languages.
    static var usesUppercaseLabels: Bool {
        (Bundle.main.preferredLocalizations.first ?? "en") != "ka"
    }
}

extension View {
    /// Small monospaced label style ("TODAY, 19:00", "3 SPOTS").
    func rvLabelStyle(_ font: Font = .rvLabel) -> some View {
        self.font(font)
            .textCase(Typography.usesUppercaseLabels ? .uppercase : nil)
            .tracking(Typography.usesUppercaseLabels ? 0.6 : 0)
    }

    /// Large serif headline that scales with Dynamic Type.
    func rvHero(size: CGFloat = 52) -> some View {
        modifier(HeroFont(size: size))
    }
}

private struct HeroFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var scaled: CGFloat = 52
    init(size: CGFloat) { _scaled = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle) }

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaled, weight: .regular, design: .serif))
            .tracking(-0.8)
            .lineSpacing(-4)
            .textCase(Typography.usesUppercaseLabels ? .uppercase : nil)
    }
}
