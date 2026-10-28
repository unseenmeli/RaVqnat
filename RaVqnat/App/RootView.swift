import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ZStack {
            switch session.phase {
            case .launching:
                LaunchView()
            case .signedOut:
                WelcomeView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlowView()
                    .transition(.move(edge: .trailing))
            case .ready:
                MainTabView()
                    .transition(.opacity)
                    .onAppear { router.consumePendingDeepLink() }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.phase)
        .task { await session.bootstrap() }
        .alert(
            Text("state.error.title"),
            isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } }),
            presenting: session.error
        ) { _ in
            Button("action.ok", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            BrandMark(size: 72)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}

/// The RaVqnat mark: three overlapping circles — people meeting.
struct BrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Theme.Palette.brand)
            ZStack {
                Circle().fill(Theme.Palette.onBrand.opacity(0.95)).frame(width: size * 0.32).offset(x: -size * 0.13, y: size * 0.08)
                Circle().fill(Theme.Palette.onBrand.opacity(0.75)).frame(width: size * 0.32).offset(x: size * 0.13, y: size * 0.08)
                Circle().fill(Theme.Palette.onBrand.opacity(0.55)).frame(width: size * 0.32).offset(y: -size * 0.14)
            }
            .blendMode(.normal)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
