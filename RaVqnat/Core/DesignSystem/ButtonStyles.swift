import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.Palette.brand
    var foreground: Color = Theme.Palette.onBrand
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rvHeadline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Theme.Spacing.l)
            .background(tint.opacity(isEnabled ? 1 : 0.4), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.25), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .subheadline.weight(.semibold) : .rvHeadline)
            .foregroundStyle(Theme.Palette.ink.opacity(isEnabled ? 1 : 0.4))
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 36 : 52)
            .padding(.horizontal, compact ? Theme.Spacing.m : Theme.Spacing.l)
            .background(Theme.Palette.surfaceMuted, in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.25), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Small pill-shaped call to action used on cards.
struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.Palette.brand
    var filled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(filled ? Theme.Palette.onBrand : tint)
            .padding(.horizontal, Theme.Spacing.l)
            .frame(minHeight: 36)
            .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.12)), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var destructive: PrimaryButtonStyle { PrimaryButtonStyle(tint: Theme.Palette.danger, foreground: .white) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondaryCompact: SecondaryButtonStyle { SecondaryButtonStyle(compact: true) }
}
