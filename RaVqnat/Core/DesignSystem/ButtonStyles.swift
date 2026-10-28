import SwiftUI

/// Solid ink block with a hard pink afterimage. Pressing pushes the button into its echo.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.Palette.ink
    var foreground: Color = Theme.Palette.canvas
    var echo: Color? = Theme.Palette.accent
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        // The face moves onto its echo while pressed; the echo stays anchored to the layout frame.
        let shift = configuration.isPressed && isEnabled ? Theme.echoOffset : 0
        configuration.label
            .rvLabelStyle(.rvButton)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, Theme.Spacing.l)
            .background(fill.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            .offset(x: shift, y: shift)
            .background {
                if let echo, isEnabled {
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(echo)
                        .offset(x: Theme.echoOffset, y: Theme.echoOffset)
                }
            }
            .padding(.trailing, Theme.echoOffset)
            .padding(.bottom, Theme.echoOffset)
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.2), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Paper block with an ink border; inverts while pressed.
struct SecondaryButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let inverted = configuration.isPressed
        configuration.label
            .rvLabelStyle(compact ? .rvCaption.weight(.bold) : .rvButton)
            .foregroundStyle((inverted ? Theme.Palette.canvas : Theme.Palette.ink).opacity(isEnabled ? 1 : 0.4))
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 36 : 54)
            .padding(.horizontal, compact ? Theme.Spacing.m : Theme.Spacing.l)
            .background(inverted ? Theme.Palette.ink : Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(Theme.Palette.ink.opacity(isEnabled ? 1 : 0.3), lineWidth: Theme.Stroke.regular))
            .contentShape(Rectangle())
    }
}

/// Small call to action used inside cards and rows.
struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.Palette.ink
    var filled = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let solid = filled != configuration.isPressed
        configuration.label
            .rvLabelStyle(.rvCaption.weight(.bold))
            .foregroundStyle(solid ? Theme.Palette.canvas : tint)
            .padding(.horizontal, Theme.Spacing.m + 2)
            .frame(minHeight: 36)
            .background(solid ? tint : Color.clear, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(tint, lineWidth: Theme.Stroke.regular))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var destructive: PrimaryButtonStyle { PrimaryButtonStyle(fill: Theme.Palette.danger, foreground: .white, echo: Theme.Palette.ink) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondaryCompact: SecondaryButtonStyle { SecondaryButtonStyle(compact: true) }
}
