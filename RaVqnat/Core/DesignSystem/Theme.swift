import SwiftUI

/// RaVqnat design tokens.
///
/// Palette: "Pomegranate" (ბროწეული) brand red on a warm "lavash" canvas, ink-plum text and a
/// Mtkvari-teal trust colour. Each token has a light and a dark value tuned for WCAG AA contrast.
enum Theme {
    enum Palette {
        static let brand = Color(light: 0xD63B2F, dark: 0xFF6F5E)
        static let onBrand = Color(light: 0xFFFFFF, dark: 0x2A0D09)
        static let brandSoft = Color(light: 0xFCE6E1, dark: 0x3A1C19)
        static let canvas = Color(light: 0xFAF6F1, dark: 0x0F0E12)
        static let surface = Color(light: 0xFFFFFF, dark: 0x1B1A20)
        static let surfaceMuted = Color(light: 0xF2ECE4, dark: 0x26242C)
        static let ink = Color(light: 0x1C1A24, dark: 0xF5F1EA)
        static let inkSecondary = Color(light: 0x5E5A66, dark: 0xABA6B3)
        static let inkTertiary = Color(light: 0x8C8794, dark: 0x7D7886)
        static let hairline = Color(light: 0xE6DED4, dark: 0x34313A)
        static let trust = Color(light: 0x0E7C7B, dark: 0x4CC9C4)
        static let trustSoft = Color(light: 0xDDF1F0, dark: 0x163433)
        static let success = Color(light: 0x2E7D4F, dark: 0x5ACB8A)
        static let warning = Color(light: 0xA45F00, dark: 0xF2B04D)
        static let warningSoft = Color(light: 0xFBEFD9, dark: 0x3A2C14)
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
        static let card: CGFloat = 24
        static let control: CGFloat = 16
        static let small: CGFloat = 10
    }
}

extension ActivityCategory {
    /// Category tint used for chips, map pins and cover art.
    var tint: Color {
        switch self {
        case .music: Color(light: 0x7B4FCF, dark: 0xB08CF5)
        case .sports: Color(light: 0x1F7A4C, dark: 0x5FCB8E)
        case .learning: Color(light: 0x2D62C8, dark: 0x7FA8F5)
        case .technology: Color(light: 0x3B4A6B, dark: 0x9AA9CC)
        case .food: Color(light: 0xC2621A, dark: 0xF2A061)
        case .arts: Color(light: 0xC23B72, dark: 0xF07FAE)
        case .outdoors: Color(light: 0x3E7D2E, dark: 0x8BCB72)
        case .games: Color(light: 0x9A7300, dark: 0xE7C24F)
        case .other: Color(light: 0x6A6475, dark: 0xB3ADBD)
        }
    }

    var softTint: Color {
        switch self {
        case .music: Color(light: 0xEFE7FB, dark: 0x2A2238)
        case .sports: Color(light: 0xE1F2E8, dark: 0x17291F)
        case .learning: Color(light: 0xE3ECFB, dark: 0x18233A)
        case .technology: Color(light: 0xE5E9F1, dark: 0x1F2430)
        case .food: Color(light: 0xFCEBDD, dark: 0x352316)
        case .arts: Color(light: 0xFBE4EE, dark: 0x351A26)
        case .outdoors: Color(light: 0xE6F1DF, dark: 0x1D2A18)
        case .games: Color(light: 0xF8F0D3, dark: 0x312912)
        case .other: Color(light: 0xEDEBF0, dark: 0x25232A)
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
    /// Rounded display face for headings; body text stays SF Pro for legibility.
    static let rvDisplay = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let rvTitle = Font.system(.title2, design: .rounded).weight(.bold)
    static let rvTitle3 = Font.system(.title3, design: .rounded).weight(.semibold)
    static let rvHeadline = Font.system(.headline, design: .rounded)
    static let rvCaption = Font.system(.caption, design: .rounded).weight(.medium)
}
