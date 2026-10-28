import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HStack {
                    Text("welcome.kicker").rvLabelStyle(.rvCaption)
                    Spacer()
                    Text(verbatim: "რავქნათ").font(.rvCaption)
                }
                .foregroundStyle(Theme.Palette.inkSecondary)

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    EchoText(text: "RaVqnat", size: 68, step: 6)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("welcome.title")
                        .font(.rvTitle)
                        .foregroundStyle(Theme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ExampleList()

                Text("welcome.subtitle")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Theme.Palette.ink)
                    .lineSpacing(3)
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Palette.surface)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.bold))
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { actions }
        .overlay { if session.isWorking { ProgressView().controlSize(.large) } }
        .screenBackground()
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.m) {
            SignInWithAppleButton(.continue) { request in
                session.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await session.handleAppleCompletion(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .disabled(session.isWorking)

            if env.auth.supportsDemoSignIn {
                Button {
                    Task { await session.signInAsDemoUser() }
                } label: {
                    Text("welcome.demo")
                }
                .buttonStyle(.secondary)
                .disabled(session.isWorking)
                .accessibilityIdentifier("welcome.demo")
                Text("welcome.demo.note")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.inkTertiary)
                    .multilineTextAlignment(.center)
            }

            Text("welcome.legal")
                .font(.caption2)
                .foregroundStyle(Theme.Palette.inkTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.s)
        .background(Theme.Palette.canvas.opacity(0.94).ignoresSafeArea())
    }
}

/// Numbered list of example plans; the highlighted row cycles, like a departures board.
/// Static under Reduce Motion.
private struct ExampleList: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlighted = 0

    private let examples: [(LocalizedStringKey, String)] = [
        ("welcome.example.guitar", "music.quarternote.3"),
        ("welcome.example.basketball", "basketball.fill"),
        ("welcome.example.coffee", "cup.and.saucer.fill"),
        ("welcome.example.chess", "checkerboard.rectangle"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                let isOn = index == highlighted
                HStack(spacing: Theme.Spacing.m) {
                    Text(verbatim: String(format: "%02d", index + 1))
                        .font(.rvCaption)
                    Text(example.0)
                        .font(.system(.title3, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Image(systemName: example.1).font(.body.weight(.semibold))
                }
                .foregroundStyle(isOn ? Theme.Palette.canvas : Theme.Palette.ink)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.m)
                .background(isOn ? Theme.Palette.ink : Color.clear)
                if index < examples.count - 1 {
                    Rectangle().fill(Theme.Palette.ink).frame(height: Theme.Stroke.hairline)
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.bold))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: highlighted)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                highlighted = (highlighted + 1) % examples.count
            }
        }
        .accessibilityElement(children: .combine)
    }
}
