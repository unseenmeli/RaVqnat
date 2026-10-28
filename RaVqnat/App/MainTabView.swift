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

/// Floating tab bar: the four main destinations share one capsule with a sliding selection pill,
/// and the create ("+") button sits on its own at the far right.
///
/// Press and hold the current tab, then drag sideways: the pill follows your finger and switches
/// pages as it passes each icon (with a selection tick), snapping into place on release.
/// Plain taps work as usual, and every item stays an ordinary button for VoiceOver.
private struct RVTabBar: View {
    @Binding var selection: AppTab
    let unreadCount: Int
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tabs: [AppTab] = [.explore, .map, .chats, .profile]
    private let barHeight: CGFloat = 62
    private let inset: CGFloat = 6

    @State private var barWidth: CGFloat = 0
    /// Finger position inside the capsule while scrubbing; nil when not dragging.
    @State private var scrubX: CGFloat?

    private var itemWidth: CGFloat { barWidth > 0 ? (barWidth - inset * 2) / CGFloat(tabs.count) : 0 }
    private var selectedIndex: Int? { tabs.firstIndex(of: selection) }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            capsule
            createButton
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.xs)
        .sensoryFeedback(.selection, trigger: selection)
    }

    // MARK: Capsule

    private var capsule: some View {
        ZStack(alignment: .leading) {
            if itemWidth > 0, let pillX = pillOffset {
                Capsule()
                    .fill(Theme.Palette.surfaceStrong)
                    .frame(width: itemWidth, height: barHeight - inset * 2)
                    .scaleEffect(scrubX == nil ? 1 : 1.08)
                    .offset(x: pillX)
                    .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.2), value: pillX)
                    .animation(reduceMotion ? nil : .spring(duration: 0.25), value: scrubX == nil)
                    .padding(.leading, inset)
            }
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, inset)
        }
        .frame(height: barHeight)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { barWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, width in barWidth = width }
        })
        .simultaneousGesture(scrubGesture)
    }

    /// Where the selection pill sits: under the finger while scrubbing, otherwise on the selected tab.
    private var pillOffset: CGFloat? {
        if let scrubX {
            return min(max(scrubX - inset - itemWidth / 2, 0), itemWidth * CGFloat(tabs.count - 1))
        }
        return selectedIndex.map { CGFloat($0) * itemWidth }
    }

    private var scrubGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                // Only the tab you are on can be picked up.
                if scrubX == nil {
                    guard index(at: drag.startLocation.x) == selectedIndex else { return }
                }
                scrubX = drag.location.x
                if let index = index(at: drag.location.x), tabs[index] != selection {
                    selection = tabs[index]
                }
            }
            .onEnded { _ in scrubX = nil }
    }

    private func index(at x: CGFloat) -> Int? {
        guard itemWidth > 0 else { return nil }
        return min(max(Int((x - inset) / itemWidth), 0), tabs.count - 1)
    }

    @ViewBuilder private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        Button { selection = tab } label: {
            Group {
                switch tab {
                case .explore: TabIcon(asset: "tab-explore", symbol: "house", isSelected: isSelected)
                case .map: TabIcon(asset: "tab-map", symbol: "map", isSelected: isSelected)
                case .chats:
                    TabIcon(asset: "tab-chats", symbol: "bubble.left.and.bubble.right", isSelected: isSelected)
                        .overlay(alignment: .topTrailing) {
                            if unreadCount > 0 {
                                Circle().fill(Theme.Palette.accent).frame(width: 9, height: 9)
                                    .overlay(Circle().stroke(Theme.Palette.canvas, lineWidth: 2))
                                    .offset(x: 4, y: -2)
                            }
                        }
                default:
                    AvatarView(name: session.profile?.displayName ?? "", url: session.profile?.avatarURL, size: 28)
                        .overlay(Circle().stroke(isSelected ? Theme.Palette.ink : .clear, lineWidth: 1.5))
                }
            }
            .foregroundStyle(isSelected ? Theme.Palette.ink : Theme.Palette.inkSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tab.titleKey))
        .accessibilityValue(tab == .chats && unreadCount > 0 ? Text("chats.unread \(unreadCount)") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }

    // MARK: Create

    private var createButton: some View {
        let isSelected = selection == .host
        return Button { selection = .host } label: {
            TabIcon(asset: "tab-create", symbol: "plus", isSelected: isSelected, size: 22, filledVariant: false)
                .fontWeight(.bold)
                .foregroundStyle(Theme.Palette.canvas)
                .frame(width: barHeight, height: barHeight)
                .background(Theme.Palette.ink, in: Circle())
                .overlay(Circle().strokeBorder(isSelected ? Theme.Palette.accent : .clear, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("tab.host"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("tab.host")
    }
}

extension AppTab {
    var titleKey: LocalizedStringKey {
        switch self {
        case .explore: "tab.explore"
        case .map: "tab.map"
        case .host: "tab.host"
        case .chats: "tab.chats"
        case .profile: "tab.profile"
        }
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
