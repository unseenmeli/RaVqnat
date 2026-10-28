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

        /// Verified badge and trust cues — calm blue, distinct from the brand pink.
        static let trust = Color(light: 0x2F6BFF, dark: 0x6FA0FF)
        static let trustSoft = Color(light: 0xE8EFFF, dark: 0x15213D)
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
        /// Top corners of full-width feed posts.
        static let post: CGFloat = 32
        static let card: CGFloat = 20
        static let control: CGFloat = 14
        static let small: CGFloat = 10
    }
}

/// Each category has a soft background and a deep tone. Colour lives in imagery and icons
/// (covers, story rings, pins, chip icons); text stays ink so contrast is never at risk.
extension ActivityCategory {
    var tint: Color {
        switch self {
        case .music: Color(light: 0x6D4AFF, dark: 0xA893FF)
        case .sports: Color(light: 0x12A150, dark: 0x4ADE80)
        case .learning: Color(light: 0x2F6BFF, dark: 0x7AA5FF)
        case .technology: Color(light: 0x3B4A63, dark: 0x9FB0CC)
        case .food: Color(light: 0xE8730C, dark: 0xFFA05C)
        case .arts: Color(light: 0xE0287D, dark: 0xFF6FB0)
        case .outdoors: Color(light: 0x2F7D4F, dark: 0x6CC28C)
        case .games: Color(light: 0xC28A00, dark: 0xF2C64B)
        case .other: Color(light: 0x5F6068, dark: 0xA5A6AE)
        }
    }

    var softTint: Color {
        switch self {
        case .music: Color(light: 0xEEE9FF, dark: 0x231C3D)
        case .sports: Color(light: 0xE3F6E9, dark: 0x14291C)
        case .learning: Color(light: 0xE6EEFF, dark: 0x15213D)
        case .technology: Color(light: 0xECEFF4, dark: 0x1E222B)
        case .food: Color(light: 0xFFEEDF, dark: 0x33220F)
        case .arts: Color(light: 0xFFE7F2, dark: 0x36182A)
        case .outdoors: Color(light: 0xE7F2EA, dark: 0x172A1E)
        case .games: Color(light: 0xFFF5D6, dark: 0x2E2610)
        case .other: Color(light: 0xF0F0F2, dark: 0x222226)
        }
    }
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
