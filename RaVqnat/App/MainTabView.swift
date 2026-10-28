import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: router.path(for: .explore)) {
                ExploreView().withAppRoutes()
            }
            .tabItem { Label("tab.explore", systemImage: "sparkles") }
            .tag(AppTab.explore)

            NavigationStack(path: router.path(for: .map)) {
                MapDiscoveryView().withAppRoutes()
            }
            .tabItem { Label("tab.map", systemImage: "map") }
            .tag(AppTab.map)

            NavigationStack(path: router.path(for: .host)) {
                HostHomeView().withAppRoutes()
            }
            .tabItem { Label("tab.host", systemImage: "plus.circle.fill") }
            .tag(AppTab.host)

            NavigationStack(path: router.path(for: .chats)) {
                ChatListView().withAppRoutes()
            }
            .tabItem { Label("tab.chats", systemImage: "bubble.left.and.bubble.right") }
            .tag(AppTab.chats)

            NavigationStack(path: router.path(for: .profile)) {
                ProfileView().withAppRoutes()
            }
            .tabItem { Label("tab.profile", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .overlay(alignment: .top) {
            if !env.network.isOnline {
                OfflineBanner().padding(.top, 4).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: env.network.isOnline)
    }
}

extension View {
    func withAppRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .activity(let id): ActivityDetailView(activityID: id)
            case .chat(let id): ChatThreadView(activityID: id)
            case .profile(let id): PublicProfileView(userID: id)
            case .manage(let id): HostManageView(activityID: id)
            case .safetyCenter: SafetyCenterView()
            }
        }
    }
}
