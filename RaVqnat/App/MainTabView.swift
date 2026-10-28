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

/// Floating tab bar: Home, Map, Messages and Profile share one capsule; the create ("+") button
/// sits on its own at the far right.
///
/// The current page shows its icon and name inside a pill. Press and hold the current page,
/// then drag sideways to scrub: labels tuck away, the pill follows your finger and pages switch
/// as it crosses each icon (with a selection tick), and it settles with the label on release.
/// Plain taps work as usual, and every item stays an ordinary button for VoiceOver.
private struct RVTabBar: View {
    @Binding var selection: AppTab
    let unreadCount: Int
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNamespace

    private let tabs: [AppTab] = [.explore, .map, .chats, .profile]
    private let barHeight: CGFloat = 62
    private let inset: CGFloat = 6
    private static let space = "rv.tabbar"

    @State private var barWidth: CGFloat = 0
    @State private var itemFrames: [AppTab: CGRect] = [:]
    /// Finger position inside the capsule while scrubbing; nil when not dragging.
    @State private var scrubX: CGFloat?

    private var isScrubbing: Bool { scrubX != nil }
    /// While scrubbing every item is the same width, so position maps directly to a tab.
    private var equalItemWidth: CGFloat { barWidth > 0 ? (barWidth - inset * 2) / CGFloat(tabs.count) : 0 }
    private var animation: Animation? { reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.18) }

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
            if isScrubbing, let scrubX, equalItemWidth > 0 {
                Capsule()
                    .fill(Theme.Palette.surfaceStrong)
                    .frame(width: equalItemWidth, height: barHeight - inset * 2)
                    .scaleEffect(1.06)
                    .offset(x: min(max(scrubX - inset - equalItemWidth / 2, 0), equalItemWidth * CGFloat(tabs.count - 1)) + inset)
            }
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in tabButton(tab) }
            }
            .padding(.horizontal, inset)
        }
        .frame(height: barHeight)
        .coordinateSpace(.named(Self.space))
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { barWidth = $0 }
        .simultaneousGesture(scrubGesture)
        .animation(animation, value: selection)
        .animation(animation, value: isScrubbing)
    }

    private var scrubGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                // Only the page you are on can be picked up.
                if scrubX == nil {
                    guard itemFrames[selection]?.insetBy(dx: -4, dy: -12).contains(drag.startLocation) == true else { return }
                }
                scrubX = drag.location.x
                guard equalItemWidth > 0 else { return }
                let index = min(max(Int((drag.location.x - inset) / equalItemWidth), 0), tabs.count - 1)
                if tabs[index] != selection { selection = tabs[index] }
            }
            .onEnded { _ in scrubX = nil }
    }

    @ViewBuilder private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        let showsLabel = isSelected && !isScrubbing
        Button { selection = tab } label: {
            HStack(spacing: 7) {
                icon(for: tab, isSelected: isSelected)
                if showsLabel {
                    Text(tab.titleKey)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                }
            }
            .foregroundStyle(isSelected ? Theme.Palette.ink : Theme.Palette.inkSecondary)
            .padding(.horizontal, showsLabel ? Theme.Spacing.l : 0)
            .frame(height: barHeight - inset * 2)
            .frame(maxWidth: showsLabel ? nil : .infinity)
            .background {
                if showsLabel {
                    Capsule().fill(Theme.Palette.surfaceStrong)
                        .matchedGeometryEffect(id: "pill", in: pillNamespace)
                }
            }
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(Self.space)) }) { itemFrames[tab] = $0 }
        .accessibilityLabel(Text(tab.titleKey))
        .accessibilityValue(tab == .chats && unreadCount > 0 ? Text("chats.unread \(unreadCount)") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }

    @ViewBuilder private func icon(for tab: AppTab, isSelected: Bool) -> some View {
        switch tab {
        case .explore: TabIcon(asset: "tab-explore", symbol: "square.grid.2x2", isSelected: isSelected, size: 22)
        case .map: TabIcon(asset: "tab-map", symbol: "location", isSelected: isSelected, size: 21)
        case .chats:
            TabIcon(asset: "tab-chats", symbol: "message", isSelected: isSelected, size: 22)
                .overlay(alignment: .topTrailing) {
                    if unreadCount > 0 {
                        Circle().fill(Theme.Palette.accent).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Theme.Palette.canvas, lineWidth: 2))
                            .offset(x: 4, y: -2)
                    }
                }
        default:
            AvatarView(name: session.profile?.displayName ?? "", url: session.profile?.avatarURL, size: 26)
                .overlay(Circle().stroke(isSelected ? Theme.Palette.ink : .clear, lineWidth: 1.5))
        }
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
            Image(systemName: isSelected && filledVariant && UIImage(systemName: "\(symbol).fill") != nil ? "\(symbol).fill" : symbol)
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
