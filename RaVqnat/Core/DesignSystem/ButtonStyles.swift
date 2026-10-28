import SwiftUI

/// Solid ink capsule — the one primary action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.Palette.ink
    var foreground: Color = Theme.Palette.canvas
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rvButton)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Theme.Spacing.l)
            .background(fill.opacity(isEnabled ? 1 : 0.25), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Soft grey capsule for secondary actions (Instagram's "Edit profile" style).
struct SecondaryButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .subheadline.weight(.semibold) : .rvButton)
            .foregroundStyle(Theme.Palette.ink.opacity(isEnabled ? 1 : 0.4))
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 36 : 54)
            .padding(.horizontal, compact ? Theme.Spacing.l : Theme.Spacing.l)
            .background(configuration.isPressed ? Theme.Palette.surfaceStrong : Theme.Palette.surfaceMuted, in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Small capsule call to action used in cards and rows.
struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.Palette.ink
    var filled = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(filled ? Theme.Palette.canvas : tint)
            .padding(.horizontal, Theme.Spacing.l)
            .frame(minHeight: 36)
            .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.Palette.surfaceMuted), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Round icon button used in custom top bars (Instagram/TikTok style).
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 40
    var material = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Theme.Palette.ink)
            .frame(width: size, height: size)
            .background {
                if material { Circle().fill(.regularMaterial) } else { Circle().fill(Theme.Palette.surfaceMuted) }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Circle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var destructive: PrimaryButtonStyle { PrimaryButtonStyle(fill: Theme.Palette.danger, foreground: .white) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondaryCompact: SecondaryButtonStyle { SecondaryButtonStyle(compact: true) }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
    static var iconOnMedia: IconButtonStyle { IconButtonStyle(material: true) }
}
