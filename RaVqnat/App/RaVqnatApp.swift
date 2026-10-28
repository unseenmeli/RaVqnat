import SwiftUI

@main
struct RaVqnatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var env: AppEnvironment
    @State private var session: AppSession
    @State private var router = AppRouter()

    init() {
        let config = AppConfig.load()
        let env = AppEnvironment.make(config: config)
        _env = State(initialValue: env)
        _session = State(initialValue: AppSession(env: env))
        if config.isUITesting { UIView.setAnimationsEnabled(false) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .environment(session)
                .environment(router)
                .tint(Theme.Palette.ink)
                .onAppear(perform: wireDelegate)
                .onOpenURL { url in
                    if let link = DeepLink(url: url) { router.handle(link, isReady: session.phase == .ready) }
                }
        }
    }

    private func wireDelegate() {
        env.reminders.registerCategories()
        appDelegate.onDeviceToken = { [env] token in env.push.didRegister(deviceToken: token) }
        appDelegate.onDeepLink = { [router, session] link in router.handle(link, isReady: session.phase == .ready) }
    }
}
