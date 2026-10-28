import SwiftUI

struct ExploreView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var model: ExploreViewModel?
    @State private var showFilters = false
    @State private var showNeighborhoodPicker = false
    @State private var pendingJoin: Activity?

    var body: some View {
        Group {
            if let model { content(model) } else { Color.clear }
        }
        .screenBackground()
        .navigationTitle(Text("tab.explore"))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard model == nil else { return }
            let model = ExploreViewModel(activities: env.activities, memberships: env.memberships)
            model.setNeighborhood(env.preferences.manualNeighborhoodID ?? session.profile?.homeNeighborhoodID)
            self.model = model
        }
    }

    @ViewBuilder
    private func content(_ model: ExploreViewModel) -> some View {
        @Bindable var model = model
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.l, pinnedViews: []) {
                header(model)
                categoryRow(model)
                quickFilters(model)
                feed(model)
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .refreshable { await model.load() }
        .task(id: model.query) { await model.load() }
        .toast($model.toast)
        .sheet(isPresented: $showFilters) {
            FilterSheet(query: $model.query)
        }
        .sheet(isPresented: $showNeighborhoodPicker) {
            NeighborhoodPickerSheet(selected: model.originNeighborhoodID) { id in
                env.preferences.manualNeighborhoodID = id
                model.setNeighborhood(id)
            }
        }
        .sheet(item: $pendingJoin) { activity in
            SafetyGuidelinesSheet {
                if let id = session.userID { env.preferences.acknowledgeSafetyGuidelines(id) }
                pendingJoin = nil
                Task { await join(activity, model: model) }
            }
        }
        .alert(Text("state.error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(model.error?.message ?? "") }
    }

    private func header(_ model: ExploreViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Menu {
                    Button {
                        Task {
                            if let coordinate = await env.location.currentLocation() {
                                model.setDeviceLocation(coordinate)
                            } else {
                                showNeighborhoodPicker = true
                            }
                        }
                    } label: { Label("explore.near_me", systemImage: "location.fill") }
                    Button { showNeighborhoodPicker = true } label: { Label("explore.choose_neighborhood", systemImage: "map") }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: model.usesDeviceLocation ? "location.fill" : "mappin").font(.caption.weight(.bold))
                        Text(model.usesDeviceLocation ? String(localized: "explore.near_you") : (Neighborhood.find(model.originNeighborhoodID)?.name ?? String(localized: "explore.all_tbilisi")))
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .rvLabelStyle()
                    .foregroundStyle(Theme.Palette.ink)
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minHeight: 36)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.hairline))
                }
                .accessibilityIdentifier("explore.location")
                Spacer()
                Button { showFilters = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.regular))
                        .overlay(alignment: .topTrailing) {
                            if model.query.activeFilterCount > 0 {
                                Text("\(model.query.activeFilterCount)")
                                    .font(.caption2.monospaced().bold()).foregroundStyle(.white)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Theme.Palette.accent, in: Rectangle())
                                    .offset(x: 5, y: -5)
                            }
                        }
                }
                .foregroundStyle(Theme.Palette.ink)
                .accessibilityLabel(Text("explore.filters"))
                .accessibilityValue(Text("explore.filters.active \(model.query.activeFilterCount)"))
            }
            Text(greeting)
                .rvHero(size: 42)
                .foregroundStyle(Theme.Palette.ink)
                .padding(.top, Theme.Spacing.m)
                .accessibilityAddTraits(.isHeader)
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

    private func categoryRow(_ model: ExploreViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                FilterChip(title: String(localized: "filter.all"), isSelected: model.query.categories.isEmpty) {
                    model.query.categories = []
                }
                ForEach(ActivityCategory.allCases) { category in
                    FilterChip(title: category.title, symbol: category.symbol, tint: category.tint,
                               isSelected: model.query.categories.contains(category)) {
                        model.toggleCategory(category)
                    }
                    .accessibilityIdentifier("explore.category.\(category.rawValue)")
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
        }
    }

    private func quickFilters(_ model: ExploreViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                quickChip(DateFilter.today.title, "sun.max", model.query.date == .today) {
                    model.query.date = model.query.date == .today ? .any : .today
                }
                quickChip(DateFilter.weekend.title, "calendar", model.query.date == .weekend) {
                    model.query.date = model.query.date == .weekend ? .any : .weekend
                }
                quickChip(String(localized: "filter.beginner"), "leaf", model.query.beginnerFriendly) {
                    model.query.beginnerFriendly.toggle()
                }
                quickChip(String(localized: "filter.has_spots"), "person.badge.plus", model.query.onlyWithSpots) {
                    model.query.onlyWithSpots.toggle()
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
        }
    }

    private func quickChip(_ title: String, _ symbol: String, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        FilterChip(title: title, symbol: symbol, tint: Theme.Palette.ink, isSelected: selected, action: action)
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
                message: model.query.activeFilterCount > 0 ? String(localized: "explore.empty.filtered") : String(localized: "explore.empty.message"),
                actionTitle: model.query.activeFilterCount > 0 ? String(localized: "explore.clear_filters") : String(localized: "explore.empty.host"),
                action: {
                    if model.query.activeFilterCount > 0 {
                        let origin = model.query.origin
                        model.query = ActivityQuery(origin: origin)
                    } else {
                        router.selectedTab = .host
                    }
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

struct FilterSheet: View {
    @Binding var query: ActivityQuery
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ActivityQuery()

    var body: some View {
        NavigationStack {
            Form {
                Section("filter.section.date") {
                    Picker(selection: $draft.date) {
                        ForEach(DateFilter.allCases) { Text($0.title).tag($0) }
                    } label: { Text("filter.date") }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("filter.section.category") {
                    ForEach(ActivityCategory.allCases) { category in
                        Toggle(isOn: Binding(
                            get: { draft.categories.contains(category) },
                            set: { if $0 { draft.categories.insert(category) } else { draft.categories.remove(category) } })) {
                            Label(category.title, systemImage: category.symbol)
                        }
                        .tint(category.tint)
                    }
                }
                Section("filter.section.neighborhood") {
                    Picker(selection: $draft.neighborhoodID) {
                        Text("filter.any_neighborhood").tag(String?.none)
                        ForEach(Neighborhood.all) { Text($0.name).tag(Optional($0.id)) }
                    } label: { Text("filter.neighborhood") }
                }
                Section {
                    Toggle("filter.has_spots", isOn: $draft.onlyWithSpots)
                    Toggle("filter.beginner", isOn: $draft.beginnerFriendly)
                }
                .tint(Theme.Palette.brand)
            }
            .navigationTitle(Text("explore.filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("filter.reset") { draft = ActivityQuery(origin: query.origin, radiusMeters: query.radiusMeters) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("filter.apply") { query = draft; dismiss() }.bold()
                }
            }
        }
        .onAppear { draft = query }
        .presentationDetents([.large])
    }
}

struct NeighborhoodPickerSheet: View {
    let selected: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button { onSelect(nil); dismiss() } label: {
                    row(String(localized: "explore.all_tbilisi"), selected == nil)
                }
                ForEach(Neighborhood.all) { hood in
                    Button { onSelect(hood.id); dismiss() } label: { row(hood.name, selected == hood.id) }
                }
            }
            .navigationTitle(Text("explore.choose_neighborhood"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, _ isSelected: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.Palette.ink)
            Spacer()
            if isSelected { Image(systemName: "checkmark").foregroundStyle(Theme.Palette.brand) }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
