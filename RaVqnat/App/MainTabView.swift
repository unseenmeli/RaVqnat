import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppEnvironment.self) private var env
    @State private var unreadCount = 0

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            tab(.explore) { ExploreView() }
            tab(.map) { MapDiscoveryView() }
            tab(.host) { HostHomeView() }
            tab(.chats) { ChatListView() }
            tab(.profile) { ProfileView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.path(for: router.selectedTab).wrappedValue.isEmpty {
                RVTabBar(selection: $router.selectedTab, unreadCount: unreadCount)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: router.path(for: router.selectedTab).wrappedValue.isEmpty)
        .overlay(alignment: .top) {
            if !env.network.isOnline {
                OfflineBanner().padding(.top, 4).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: env.network.isOnline)
        .task(id: router.selectedTab) { await refreshUnread() }
        .task(id: router.chatsPath.count) { await refreshUnread() }
    }

    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            content().withAppRoutes()
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(tab)
    }

    private func refreshUnread() async {
        unreadCount = ((try? await env.chat.threads()) ?? []).reduce(0) { $0 + $1.unreadCount }
    }
}

/// Icon-only tab bar with a prominent centre "create" button.
private struct RVTabBar: View {
    @Binding var selection: AppTab
    let unreadCount: Int
    @Environment(AppSession.self) private var session

    var body: some View {
        HStack(spacing: 0) {
            item(.explore, asset: "tab-explore", symbol: "house", label: "tab.explore")
            item(.map, asset: "tab-map", symbol: "map", label: "tab.map")
            createButton
            item(.chats, asset: "tab-chats", symbol: "bubble.left.and.bubble.right", label: "tab.chats", badge: unreadCount > 0)
            profileItem
        }
        .padding(.horizontal, Theme.Spacing.s)
        .frame(height: 56)
        .background(Theme.Palette.canvas.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider().overlay(Theme.Palette.hairline) }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func item(_ tab: AppTab, asset: String, symbol: String, label: LocalizedStringKey, badge: Bool = false) -> some View {
        let isSelected = selection == tab
        return Button { selection = tab } label: {
            TabIcon(asset: asset, symbol: symbol, isSelected: isSelected)
                .foregroundStyle(isSelected ? Theme.Palette.ink : Theme.Palette.inkSecondary)
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle().fill(Theme.Palette.accent).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Theme.Palette.canvas, lineWidth: 2))
                            .offset(x: 4, y: -2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityValue(badge ? Text("chats.unread \(unreadCount)") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }

    private var createButton: some View {
        let isSelected = selection == .host
        return Button { selection = .host } label: {
            TabIcon(asset: "tab-create", symbol: "plus", isSelected: isSelected, size: 20, filledVariant: false)
                .foregroundStyle(isSelected ? Theme.Palette.ink : Theme.Palette.canvas)
                .frame(width: 48, height: 34)
                .background(isSelected ? Theme.Palette.surfaceMuted : Theme.Palette.ink,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("tab.host"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("tab.host")
    }

    private var profileItem: some View {
        let isSelected = selection == .profile
        return Button { selection = .profile } label: {
            AvatarView(name: session.profile?.displayName ?? "", url: session.profile?.avatarURL, size: 26)
                .padding(2)
                .overlay(Circle().stroke(isSelected ? Theme.Palette.ink : .clear, lineWidth: 1.5))
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("tab.profile"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("tab.profile")
    }
}

/// Tab icon that uses a custom asset when one is provided and falls back to an SF Symbol.
///
/// Custom icons live in Assets.xcassets as template images named `tab-<name>` (unselected) and
/// `tab-<name>-selected` (optional). Names: tab-explore, tab-map, tab-create, tab-chats.
private struct TabIcon: View {
    let asset: String
    let symbol: String
    let isSelected: Bool
    var size: CGFloat = 24
    var filledVariant = true

    var body: some View {
        if let name = assetName {
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: isSelected && filledVariant ? "\(symbol).fill" : symbol)
                .font(.system(size: size * 0.92, weight: isSelected ? .semibold : .regular))
        }
    }

    private var assetName: String? {
        let selectedName = "\(asset)-selected"
        if isSelected, UIImage(named: selectedName) != nil { return selectedName }
        return UIImage(named: asset) != nil ? asset : nil
    }
}

extension View {
    func withAppRoutes() -> some View {
        tint(Theme.Palette.ink)
            .navigationDestination(for: Route.self) { route in
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
