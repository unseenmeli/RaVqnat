import SwiftUI

struct ExploreView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var model: ExploreViewModel?
    @State private var stories: StoriesViewModel?
    @State private var showFilters = false
    @State private var showComposer = false
    @State private var viewerStart: StoryViewerStart?
    @State private var pendingJoin: Activity?

    var body: some View {
        Group {
            if let model, let stories { content(model, stories) } else { Color.clear }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard model == nil else { return }
            let model = ExploreViewModel(activities: env.activities, memberships: env.memberships)
            model.configure(homeNeighborhoodID: session.profile?.homeNeighborhoodID)
            self.model = model
            self.stories = StoriesViewModel(repository: env.stories)
        }
    }

    @ViewBuilder
    private func content(_ model: ExploreViewModel, _ stories: StoriesViewModel) -> some View {
        @Bindable var model = model
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header(model)
                StoriesRow(groups: stories.groups, onAdd: { showComposer = true }) { index in
                    viewerStart = StoryViewerStart(index: index)
                }
                if !model.filters.isEmpty { activeFilters(model) }
                feed(model)
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .refreshable { await model.load(); await stories.load() }
        .task(id: model.query) { await model.load() }
        .task { await stories.load() }
        .toast($model.toast)
        .sheet(isPresented: $showFilters) {
            FilterSheet(initial: model.filters) { filters in
                Task { await model.apply(filters, location: env.location) }
            }
        }
        .sheet(isPresented: $showComposer) {
            StoryComposer { Task { await stories.load() } }
        }
        .fullScreenCover(item: $viewerStart, onDismiss: { Task { await stories.load() } }) { start in
            StoryViewer(groups: stories.groups, startGroup: start.index, viewerID: session.userID,
                        onSeen: stories.markSeen,
                        onDelete: { story in Task { await stories.delete(story) } },
                        onOpenActivity: { id in router.explorePath.append(.activity(id)) })
        }
        .sheet(item: $pendingJoin) { activity in
            SafetyGuidelinesSheet {
                if let id = session.userID { env.preferences.acknowledgeSafetyGuidelines(id) }
                pendingJoin = nil
                Task { await join(activity, model: model) }
            }
        }
        .alert(Text("map.location_denied.title"), isPresented: $model.locationUnavailable) {
            Button("filter.open") { showFilters = true }
            Button("action.open_settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            Button("action.cancel", role: .cancel) {}
        } message: { Text("map.location_denied.message") }
        .alert(Text("state.error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(model.error?.message ?? "") }
    }

    private func header(_ model: ExploreViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(spacing: Theme.Spacing.s) {
                Wordmark()
                Spacer()
                Button { showFilters = true } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.icon)
                    .overlay(alignment: .topTrailing) {
                        if !model.filters.isEmpty {
                            Circle().fill(Theme.Palette.accent).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Theme.Palette.canvas, lineWidth: 2))
                        }
                    }
                    .accessibilityLabel(Text("explore.filters"))
                    .accessibilityValue(Text(model.filters.summary.joined(separator: ", ")))
                    .accessibilityIdentifier("explore.filters")
            }
            Text(greeting)
                .rvHero(size: 30)
                .foregroundStyle(Theme.Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("explore.greeting")
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, Theme.Spacing.s)
    }

    private var greeting: String {
        if let name = session.profile?.displayName.split(separator: " ").first {
            return String(localized: "explore.greeting.named \(String(name))")
        }
        return String(localized: "explore.greeting")
    }

    /// One calm chip that says what's applied; tapping edits, ✕ clears.
    private func activeFilters(_ model: ExploreViewModel) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Button { showFilters = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease").font(.footnote.weight(.semibold))
                    Text(model.filters.summary.joined(separator: " · ")).lineLimit(1)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.ink)
            }
            .buttonStyle(.plain)
            Button { model.clearFilters() } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(Theme.Palette.inkSecondary)
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel(Text("explore.clear_filters"))
            .accessibilityIdentifier("explore.clear_filters")
        }
        .padding(.leading, Theme.Spacing.l)
        .padding(.trailing, Theme.Spacing.s)
        .frame(minHeight: 40)
        .background(Theme.Palette.surfaceMuted, in: Capsule())
        .padding(.horizontal, Theme.Spacing.screen)
    }

    @ViewBuilder
    private func feed(_ model: ExploreViewModel) -> some View {
        switch model.state {
        case .idle, .loading:
            ForEach(0..<3, id: \.self) { _ in ActivityCardSkeleton().padding(.horizontal, Theme.Spacing.screen) }
        case .failed(let error):
            ErrorStateView(error: error) { Task { await model.load() } }
        case .loaded(let items) where items.isEmpty:
            EmptyStateView(
                symbol: "sparkles",
                title: String(localized: "explore.empty.title"),
                message: model.filters.isEmpty ? String(localized: "explore.empty.message") : String(localized: "explore.empty.filtered"),
                actionTitle: model.filters.isEmpty ? String(localized: "explore.empty.host") : String(localized: "explore.clear_filters"),
                action: {
                    if model.filters.isEmpty { router.selectedTab = .host } else { model.clearFilters() }
                })
        case .loaded(let items):
            ForEach(items) { activity in
                NavigationLink(value: Route.activity(activity.id)) {
                    ActivityCard(activity: activity, viewerID: session.userID,
                                 isJoining: model.joiningIDs.contains(activity.id)) {
                        startJoin(activity, model: model)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("activity.card.\(activity.id.uuidString)")
                .padding(.horizontal, Theme.Spacing.screen)
                .task { await model.loadMoreIfNeeded(current: activity) }
            }
            if model.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
    }

    private func startJoin(_ activity: Activity, model: ExploreViewModel) {
        guard let userID = session.userID else { return }
        if env.preferences.hasAcknowledgedSafetyGuidelines(userID) {
            Task { await join(activity, model: model) }
        } else {
            pendingJoin = activity
        }
    }

    private func join(_ activity: Activity, model: ExploreViewModel) async {
        if await model.requestJoin(activity) {
            await env.push.requestAuthorizationIfNeeded()
        }
    }
}

struct StoryViewerStart: Identifiable {
    let index: Int
    var id: Int { index }
}
