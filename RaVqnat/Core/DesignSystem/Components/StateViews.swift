import SwiftUI

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.Palette.ink)
                .frame(width: 72, height: 72)
                .background(Theme.Palette.surfaceMuted, in: Circle())
                .accessibilityHidden(true)
            Text(title).font(.rvTitle3).foregroundStyle(Theme.Palette.ink).multilineTextAlignment(.center)
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
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.Palette.canvas)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Palette.ink, in: Capsule())
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

    /// Borderless soft-grey card.
    func rvCard(padding: CGFloat = Theme.Spacing.l) -> some View {
        self.padding(padding)
            .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    func screenBackground() -> some View {
        background(Theme.Palette.canvas.ignoresSafeArea())
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
                Text(trailing).font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary)
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
            .background(Theme.Palette.ink, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
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

