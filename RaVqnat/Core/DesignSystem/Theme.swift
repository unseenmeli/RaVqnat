import SwiftUI

/// RaVqnat design tokens — modern and minimal.
///
/// Monochrome UI (pure white / true black), soft grey surfaces, SF Pro with tight bold headings,
/// capsule controls and borderless cards. A single accent (pink) is reserved for small signals:
/// the verified check, unread dots, the active tab indicator and event times.
enum Theme {
    enum Palette {
        static let canvas = Color(light: 0xFFFFFF, dark: 0x000000)
        static let surface = Color(light: 0xFFFFFF, dark: 0x111113)
        static let surfaceMuted = Color(light: 0xF2F2F4, dark: 0x1C1C1F)
        static let surfaceStrong = Color(light: 0xE6E6E9, dark: 0x2A2A2E)
        static let ink = Color(light: 0x0A0A0A, dark: 0xFAFAFA)
        static let inkSecondary = Color(light: 0x6B6B70, dark: 0x9A9AA0)
        static let inkTertiary = Color(light: 0x9E9EA4, dark: 0x6A6A70)
        static let hairline = Color(light: 0xE8E8EB, dark: 0x262629)

        /// Accent for small signals only. `accentText` passes AA as text on canvas.
        static let accent = Color(light: 0xFF2E9A, dark: 0xFF4FAE)
        static let accentText = Color(light: 0xD1147A, dark: 0xFF6BBB)

        // Primary actions are ink with canvas-coloured text (inverted in dark mode).
        static let brand = ink
        static let onBrand = canvas
        static let brandSoft = surfaceMuted

        static let trust = accent
        static let trustSoft = surfaceMuted
        static let success = Color(light: 0x16A34A, dark: 0x4ADE80)
        static let warning = Color(light: 0xB45309, dark: 0xFBBF24)
        static let warningSoft = Color(light: 0xFEF3C7, dark: 0x332810)
        static let danger = Color(light: 0xDC2626, dark: 0xF87171)
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
        static let card: CGFloat = 20
        static let control: CGFloat = 14
        static let small: CGFloat = 10
    }
}

extension ActivityCategory {
    var tint: Color { Theme.Palette.ink }
    var softTint: Color { Theme.Palette.surfaceMuted }
}

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
    static let rvDisplay = Font.largeTitle.weight(.bold)
    static let rvTitle = Font.title2.weight(.bold)
    static let rvTitle3 = Font.title3.weight(.semibold)
    static let rvHeadline = Font.headline
    static let rvCaption = Font.caption.weight(.semibold)
    static let rvLabel = Font.footnote.weight(.semibold)
    static let rvButton = Font.body.weight(.semibold)
}

extension View {
    /// Small secondary label style (metadata, tags).
    func rvLabelStyle(_ font: Font = .rvLabel) -> some View {
        self.font(font)
    }

    /// Large, tight, bold headline that scales with Dynamic Type.
    func rvHero(size: CGFloat = 40) -> some View {
        modifier(HeroFont(size: size))
    }
}

private struct HeroFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var scaled: CGFloat = 40
    init(size: CGFloat) { _scaled = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle) }

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaled, weight: .bold))
            .tracking(-0.6)
    }
}
