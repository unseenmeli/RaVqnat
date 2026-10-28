import SwiftUI

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            EchoSymbol(symbol: symbol, size: 40)
                .frame(width: 96, height: 88)
                .accessibilityHidden(true)
            Text(title).font(.rvTitle).foregroundStyle(Theme.Palette.ink).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PillButtonStyle())
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let error: AppError
    var retry: (() -> Void)?

    var body: some View {
        EmptyStateView(
            symbol: error == .offline ? "wifi.slash" : "exclamationmark.triangle.fill",
            title: error == .offline ? String(localized: "state.offline.title") : String(localized: "state.error.title"),
            message: error.message,
            actionTitle: retry != nil && error.isRetryable ? String(localized: "action.try_again") : nil,
            action: retry
        )
    }
}

struct OfflineBanner: View {
    var body: some View {
        Label("state.offline.banner", systemImage: "wifi.slash")
            .rvLabelStyle(.rvCaption.weight(.bold))
            .foregroundStyle(Theme.Palette.canvas)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Palette.ink, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .accessibilityAddTraits(.isStaticText)
    }
}

/// Shimmering placeholder. Becomes a static placeholder when Reduce Motion is on.
struct SkeletonModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, Theme.Palette.surface.opacity(0.6), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.6)
                            .offset(x: phase * proxy.size.width * 1.6)
                    }
                    .mask(content.redacted(reason: .placeholder))
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
            }
            .accessibilityHidden(true)
    }
}

extension View {
    func skeleton(_ active: Bool = true) -> some View {
        modifier(SkeletonActiveModifier(active: active))
    }

    /// Paper card with an ink hairline border.
    func rvCard(padding: CGFloat = Theme.Spacing.l) -> some View {
        self.padding(padding)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.hairline))
    }

    /// Hard offset shadow ("afterimage") behind a shape, drawn in the layout frame.
    func echoShadow(_ color: Color = Theme.Palette.ink, offset: CGFloat = Theme.echoOffset, cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        self.background {
            RoundedRectangle(cornerRadius: cornerRadius).fill(color).offset(x: offset, y: offset)
        }
        .padding(.trailing, offset)
        .padding(.bottom, offset)
    }

    /// Warm dot-grid paper behind a whole screen.
    func screenBackground() -> some View {
        background(DotPaper().ignoresSafeArea())
    }
}

private struct SkeletonActiveModifier: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.modifier(SkeletonModifier()) } else { content }
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.rvTitle3).foregroundStyle(Theme.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing {
                Text(trailing).rvLabelStyle(.rvCaption).foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }
}

/// Toast-style confirmation shown at the top of a screen.
struct ToastView: View {
    let message: String
    var symbol = "checkmark.circle.fill"
    var tint = Theme.Palette.success

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Palette.canvas)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background(Theme.Palette.ink, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            .echoShadow(Theme.Palette.accent, offset: 3, cornerRadius: Theme.Radius.control)
    }
}

extension View {
    /// Shows a transient toast; the binding is cleared automatically.
    func toast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .top) {
            if let text = message.wrappedValue {
                ToastView(message: text)
                    .padding(.top, Theme.Spacing.s)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { message.wrappedValue = nil }
                    }
                    .accessibilityAddTraits(.updatesFrequently)
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: text) }
            }
        }
        .animation(.spring(duration: 0.35), value: message.wrappedValue)
    }
}

/// ECHO-style dot grid on warm paper. Rendered once into a tile image.
struct DotPaper: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Theme.Palette.canvas
            .overlay(Image(uiImage: Self.tile(dark: colorScheme == .dark)).resizable(resizingMode: .tile))
            .accessibilityHidden(true)
    }

    @MainActor private static var cache: [Bool: UIImage] = [:]

    @MainActor private static func tile(dark: Bool) -> UIImage {
        if let cached = cache[dark] { return cached }
        let size = CGSize(width: 22, height: 22)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hex: dark ? 0xF3F1EC : 0x3C3C43, alpha: dark ? 0.09 : 0.14).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 10, y: 10, width: 2, height: 2))
        }
        cache[dark] = image
        return image
    }
}

/// A symbol with two trailing pink afterimages — the RaVqnat "echo".
struct EchoSymbol: View {
    let symbol: String
    var size: CGFloat = 40
    var spacing: CGFloat?

    var body: some View {
        let step = spacing ?? size * 0.16
        ZStack {
            Image(systemName: symbol).foregroundStyle(Theme.Palette.accent.opacity(0.3)).offset(x: -step * 2)
            Image(systemName: symbol).foregroundStyle(Theme.Palette.accent.opacity(0.85)).offset(x: -step)
            Image(systemName: symbol).foregroundStyle(Theme.Palette.ink)
        }
        .font(.system(size: size, weight: .bold))
    }
}

/// Text with trailing pink afterimages, used for hero headlines.
struct EchoText: View {
    let text: String
    var size: CGFloat = 64
    var step: CGFloat = 5

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text).foregroundStyle(Theme.Palette.accent.opacity(0.28)).offset(x: -step * 2)
            Text(text).foregroundStyle(Theme.Palette.accent.opacity(0.8)).offset(x: -step)
            Text(text).foregroundStyle(Theme.Palette.ink)
        }
        .rvHero(size: size)
        .padding(.leading, step * 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }
}
