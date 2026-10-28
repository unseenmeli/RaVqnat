import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    private static let examples: [(LocalizedStringKey, String)] = [
        ("welcome.example.guitar", "music.note"),
        ("welcome.example.basketball", "basketball.fill"),
        ("welcome.example.coffee", "cup.and.saucer.fill"),
        ("welcome.example.chess", "checkerboard.rectangle"),
        ("welcome.example.photo", "camera.fill"),
        ("welcome.example.hike", "mountain.2.fill"),
        ("welcome.example.english", "character.bubble.fill"),
        ("welcome.example.games", "dice.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Wordmark()
                Text(verbatim: "რავქნათ").font(.subheadline).foregroundStyle(Theme.Palette.inkTertiary)
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.s)

            Spacer(minLength: Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.m) {
                Marquee(items: Array(Self.examples.prefix(4)), speed: 22)
                Marquee(items: Array(Self.examples.suffix(4)), speed: -18)
            }
            .accessibilityHidden(true)

            Spacer(minLength: Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text("welcome.title")
                    .rvHero(size: 44)
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("welcome.subtitle")
                    .font(.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Spacing.screen)

            VStack(spacing: Theme.Spacing.m) {
                SignInWithAppleButton(.continue) { request in
                    session.prepareAppleRequest(request)
                } onCompletion: { result in
                    Task { await session.handleAppleCompletion(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(Capsule())
                .disabled(session.isWorking)

                if env.auth.supportsDemoSignIn {
                    Button("welcome.demo") { Task { await session.signInAsDemoUser() } }
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
            .padding(.bottom, Theme.Spacing.s)
        }
        .overlay { if session.isWorking { ProgressView().controlSize(.large) } }
        .screenBackground()
    }
}

/// Lowercase bold wordmark with the accent dot.
struct Wordmark: View {
    var size: CGFloat = 26

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(verbatim: "ravqnat")
                .font(.system(size: size, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(Theme.Palette.ink)
            Circle().fill(Theme.Palette.accent).frame(width: size * 0.24, height: size * 0.24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "RaVqnat"))
    }
}

/// A row of example chips drifting horizontally. Static under Reduce Motion.
private struct Marquee: View {
    let items: [(LocalizedStringKey, String)]
    /// Points per second; negative drifts the other way.
    let speed: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        // The GeometryReader pins the row to the screen width; the chips inside are wider and
        // would otherwise widen the whole screen.
        GeometryReader { container in
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let travel = contentWidth > 0 ? (timeline.date.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: contentWidth) : 0
                let offset = reduceMotion ? 0 : (speed > 0 ? -travel : -contentWidth - travel)
                HStack(spacing: Theme.Spacing.s) {
                    row.background(GeometryReader { proxy in
                        Color.clear.onAppear { contentWidth = proxy.size.width + Theme.Spacing.s }
                    })
                    row
                    row
                }
                .fixedSize()
                .offset(x: offset + Theme.Spacing.screen)
            }
            .frame(width: container.size.width, height: 48, alignment: .leading)
            .clipped()
        }
        .frame(height: 48)
    }

    private var row: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: item.1).font(.subheadline.weight(.semibold))
                    Text(item.0).font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, Theme.Spacing.l)
                .frame(height: 48)
                .background(Theme.Palette.surfaceMuted, in: Capsule())
                .fixedSize()
            }
        }
    }
}
