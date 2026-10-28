import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Spacing.xl)
            WelcomeCollage()
                .frame(height: 260)
                .padding(.horizontal, Theme.Spacing.screen)
            Spacer(minLength: Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.s) {
                    BrandMark(size: 36)
                    Text(verbatim: "RaVqnat · რავქნათ")
                        .font(.rvHeadline)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                Text("welcome.title")
                    .font(.rvDisplay)
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("welcome.subtitle")
                    .font(.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.screen)

            VStack(spacing: Theme.Spacing.m) {
                SignInWithAppleButton(.continue) { request in
                    session.prepareAppleRequest(request)
                } onCompletion: { result in
                    Task { await session.handleAppleCompletion(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .clipShape(Capsule())
                .disabled(session.isWorking)

                if env.auth.supportsDemoSignIn {
                    Button {
                        Task { await session.signInAsDemoUser() }
                    } label: {
                        Label("welcome.demo", systemImage: "hammer.fill")
                    }
                    .buttonStyle(.secondary)
                    .disabled(session.isWorking)
                    .accessibilityIdentifier("welcome.demo")
                    Text("welcome.demo.note")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                        .multilineTextAlignment(.center)
                }

                Text("welcome.legal")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.inkTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .overlay { if session.isWorking { ProgressView().controlSize(.large) } }
        .screenBackground()
    }
}

/// Playful arrangement of category tiles that previews what the app is about.
private struct WelcomeCollage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let tiles: [(ActivityCategory, CGFloat, CGFloat, Double, CGFloat)] = [
        (.music, -0.28, -0.22, -8, 112), (.sports, 0.22, -0.30, 6, 96), (.food, 0.30, 0.18, -5, 120),
        (.games, -0.24, 0.26, 7, 100), (.outdoors, 0.0, 0.0, 0, 132),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                    let (category, x, y, angle, size) = tile
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(category.softTint)
                        .overlay {
                            Image(systemName: category.symbol)
                                .font(.system(size: size * 0.38, weight: .bold))
                                .foregroundStyle(category.tint)
                        }
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
                        .rotationEffect(.degrees(angle))
                        .offset(x: x * proxy.size.width, y: y * proxy.size.height)
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                        .opacity(appeared || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.35).delay(Double(index) * 0.06), value: appeared)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear { appeared = true }
        .accessibilityHidden(true)
    }
}
