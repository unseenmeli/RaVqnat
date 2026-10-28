import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @State private var hosted: [Activity] = []
    @State private var joined: [Activity] = []
    @State private var gridTab: ProfileGridTab = .joined
    @State private var showEdit = false
    @State private var showVerification = false

    var body: some View {
        ScrollView {
            if let profile = session.profile {
                VStack(spacing: Theme.Spacing.l) {
                    ProfileHeader(
                        name: profile.displayName, avatarURL: profile.avatarURL, isVerified: profile.isVerified,
                        neighborhoodID: profile.homeNeighborhoodID, bio: profile.bio, interestIDs: profile.interestIDs,
                        stats: [
                            (String(hosted.count), String(localized: "profile.stat.hosted")),
                            (String(joined.filter { $0.myMembership?.occupiesSpot == true }.count), String(localized: "profile.stat.joined")),
                            (String((hosted + joined).filter { !$0.hasEnded() && $0.status == .published }.count), String(localized: "profile.stat.upcoming")),
                        ])
                    HStack(spacing: Theme.Spacing.s) {
                        Button("profile.edit") { showEdit = true }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("profile.edit")
                        Button { showVerification = true } label: {
                            Label(profile.isVerified ? String(localized: "verification.status.verified") : String(localized: "profile.get_verified"),
                                  systemImage: profile.isVerified ? "checkmark.seal.fill" : "checkmark.seal")
                        }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, Theme.Spacing.screen)

                    ProfileGrid(tab: $gridTab, tabs: [.joined, .hosted], items: gridTab == .hosted ? hosted : joined)
                }
                .padding(.top, Theme.Spacing.s)
            }
        }
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Text(session.profile?.displayName ?? "").font(.headline)
                    if session.profile?.isVerified == true { VerifiedBadge(size: .caption) }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "line.3.horizontal") }
                    .accessibilityLabel(Text("settings.title"))
                    .accessibilityIdentifier("profile.settings")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await session.refreshProfile(); await load() }
        .sheet(isPresented: $showEdit) { EditProfileView() }
        .sheet(isPresented: $showVerification) { VerificationView { Task { await session.refreshProfile() } } }
    }

    private func load() async {
        async let hosted = env.activities.hostedActivities()
        async let joined = env.activities.joinedActivities()
        self.hosted = (try? await hosted) ?? []
        self.joined = (try? await joined) ?? []
    }
}

/// Centred header shared by your own and other people's profiles (TikTok/Instagram layout).
struct ProfileHeader: View {
    let name: String
    let avatarURL: URL?
    let isVerified: Bool
    let neighborhoodID: String?
    let bio: String
    let interestIDs: [String]
    let stats: [(value: String, label: String)]

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            AvatarView(name: name, url: avatarURL, size: 96)
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(name).font(.title3.weight(.bold))
                    if isVerified { VerifiedBadge(size: .subheadline) }
                }
                if let hood = Neighborhood.find(neighborhoodID) {
                    Label(hood.name, systemImage: "mappin").font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    VStack(spacing: 2) {
                        Text(stat.value).font(.headline.monospacedDigit())
                        Text(stat.label).font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    if index < stats.count - 1 {
                        Rectangle().fill(Theme.Palette.hairline).frame(width: 1, height: 24)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            if !bio.isEmpty {
                Text(bio).font(.subheadline).multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)
            }
            if !interestIDs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(interestIDs.compactMap(Interest.find)) { interest in
                            StatusPill(text: interest.title, symbol: interest.category.symbol)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screen)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
        }
        .foregroundStyle(Theme.Palette.ink)
    }
}

enum ProfileGridTab: Hashable {
    case joined, hosted, upcoming

    var symbol: String {
        switch self {
        case .joined: "ticket"
        case .hosted: "star"
        case .upcoming: "calendar"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .joined: "profile.joined"
        case .hosted: "profile.hosted"
        case .upcoming: "profile.upcoming_hosted"
        }
    }

    var emptyMessage: String {
        switch self {
        case .joined: String(localized: "profile.joined.empty")
        case .hosted: String(localized: "profile.hosted.empty")
        case .upcoming: String(localized: "profile.upcoming.empty")
        }
    }
}

/// Icon tabs with an underline indicator above a 3-column grid of activity tiles.
struct ProfileGrid: View {
    @Binding var tab: ProfileGridTab
    let tabs: [ProfileGridTab]
    let items: [Activity]
    @Namespace private var underline

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { candidate in
                    Button { withAnimation(.spring(duration: 0.3)) { tab = candidate } } label: {
                        VStack(spacing: 10) {
                            Image(systemName: tab == candidate ? "\(candidate.symbol).fill" : candidate.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(tab == candidate ? Theme.Palette.ink : Theme.Palette.inkTertiary)
                            ZStack {
                                Rectangle().fill(Color.clear).frame(height: 2)
                                if tab == candidate {
                                    Rectangle().fill(Theme.Palette.ink).frame(width: 44, height: 2)
                                        .matchedGeometryEffect(id: "underline", in: underline)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(candidate.label))
                    .accessibilityAddTraits(tab == candidate ? .isSelected : [])
                }
            }
            .overlay(alignment: .bottom) { Divider().overlay(Theme.Palette.hairline) }
            .sensoryFeedback(.selection, trigger: tab)

            if items.isEmpty {
                Text(tab.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, Theme.Spacing.xxl)
                    .padding(.horizontal, Theme.Spacing.xl)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(items) { activity in
                        NavigationLink(value: Route.activity(activity.id)) { ActivityTile(activity: activity) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// Portrait grid tile: cover with the date on top and the title at the bottom.
private struct ActivityTile: View {
    let activity: Activity

    var body: some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                ActivityCoverArt(category: activity.category, seed: activity.id, imageURL: activity.coverImageURL)
            }
            .overlay(alignment: .bottomLeading) {
                Text(activity.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    if activity.status == .cancelled {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Palette.danger)
                    } else if activity.myMembership == .pending {
                        Image(systemName: "clock.fill")
                    }
                    Text(activity.startsAt.formatted(.dateTime.day().month(.abbreviated)))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.thinMaterial, in: Capsule())
                .padding(6)
            }
            .clipped()
            .opacity(activity.status == .cancelled || activity.hasEnded() ? 0.6 : 1)
            .accessibilityElement(children: .combine)
    }
}

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @State private var showVerification = false

    var body: some View {
        List {
            Section {
                NavigationLink { NotificationSettingsView() } label: { Label("profile.notifications", systemImage: "bell") }
                Button { showVerification = true } label: {
                    HStack {
                        Label("profile.verification", systemImage: "checkmark.seal")
                        Spacer()
                        Text(session.profile?.isVerified == true ? VerificationStatus.verified.title : (session.profile?.verification.status.title ?? ""))
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    HStack {
                        Label("profile.app_language", systemImage: "globe")
                        Spacer()
                        Text(Locale.current.localizedString(forLanguageCode: Bundle.main.preferredLocalizations.first ?? "en") ?? "")
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }
            } header: { Text("profile.section.account") }
            .foregroundStyle(Theme.Palette.ink)

            Section("profile.section.safety") {
                NavigationLink(value: Route.safetyCenter) { Label("safety.center.title", systemImage: "shield.lefthalf.filled") }
            }

            Section {
                Button("profile.sign_out") { Task { await session.signOut() } }
                    .foregroundStyle(Theme.Palette.ink)
                NavigationLink { DeleteAccountView() } label: { Text("profile.delete").foregroundStyle(Theme.Palette.danger) }
            } footer: {
                Text(verbatim: "RaVqnat \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")\(env.config.isMockMode ? " · demo" : "")")
            }
        }
        .navigationTitle(Text("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showVerification) { VerificationView { Task { await session.refreshProfile() } } }
    }
}

/// Another person's profile. Shows only public information — never contact details.
struct PublicProfileView: View {
    let userID: UUID
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState<PublicProfile> = .idle
    @State private var upcoming: [Activity] = []
    @State private var gridTab: ProfileGridTab = .upcoming
    @State private var reportTarget: ReportTarget?
    @State private var showBlock = false
    @State private var error: AppError?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error): ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let profile): content(profile)
            }
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $reportTarget) { target in ReportSheet(target: target) { showBlock = true } }
        .blockConfirmation(userName: state.value?.displayName, isPresented: $showBlock) {
            Task {
                do { try await env.safety.block(userID: userID); Haptics.success(); dismiss() }
                catch { self.error = AppError.from(error) }
            }
        }
        .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(error?.message ?? "") }
    }

    private func content(_ profile: PublicProfile) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                ProfileHeader(
                    name: profile.displayName, avatarURL: profile.avatarURL, isVerified: profile.isVerified,
                    neighborhoodID: nil, bio: profile.bio, interestIDs: profile.interestIDs,
                    stats: [
                        (String(profile.hostedActivityCount), String(localized: "profile.stat.hosted")),
                        (profile.memberSince.formatted(.dateTime.month(.abbreviated).year()), String(localized: "profile.stat.member_since")),
                    ])
                if profile.isVerified {
                    Text("profile.verified_note")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xxl)
                }
                ProfileGrid(tab: $gridTab, tabs: [.upcoming], items: upcoming)
            }
            .padding(.top, Theme.Spacing.s)
        }
        .toolbar {
            ToolbarItem(placement: .principal) { Text(profile.displayName).font(.headline) }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { reportTarget = ReportTarget(userID: profile.id, userName: profile.displayName) } label: {
                        Label("detail.report", systemImage: "flag")
                    }
                    Button(role: .destructive) { showBlock = true } label: { Label("profile.block", systemImage: "hand.raised.slash") }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel(Text("detail.more"))
            }
        }
    }

    private func load() async {
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await env.profiles.profile(id: userID))
            upcoming = (try? await env.activities.activities(hostedBy: userID)) ?? []
        } catch {
            state = .failed(AppError.from(error))
        }
    }
}

struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var update = ProfileUpdate(displayName: "", bio: "", interestIDs: [], preferredLanguage: .en, homeNeighborhoodID: nil)
    @State private var photoData: Data?
    @State private var isSaving = false
    @State private var error: AppError?

    var body: some View {
        NavigationStack {
            Form {
                Section { AvatarPicker(name: update.displayName, data: $photoData).frame(maxWidth: .infinity) }
                    .listRowBackground(Color.clear)
                Section("edit.name") {
                    TextField(text: $update.displayName) { Text("onboarding.name.placeholder") }
                    if let issue = OnboardingValidator.nameIssue(update.displayName) {
                        Text(issue.message).font(.footnote).foregroundStyle(Theme.Palette.danger)
                    }
                }
                Section {
                    TextField(text: $update.bio, axis: .vertical) { Text("edit.bio.placeholder") }.lineLimit(2...5)
                } header: { Text("edit.bio") } footer: {
                    Text("edit.bio.count \(update.bio.count) \(OnboardingValidator.bioLimit)")
                }
                Section("edit.interests") {
                    InterestPicker(selected: update.interestIDs) { id in
                        if let i = update.interestIDs.firstIndex(of: id) { update.interestIDs.remove(at: i) }
                        else if update.interestIDs.count < OnboardingValidator.maxInterests { update.interestIDs.append(id) }
                    }
                }
                Section {
                    Picker(selection: $update.preferredLanguage) {
                        ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                    } label: { Text("edit.language") }
                    Picker(selection: $update.homeNeighborhoodID) {
                        ForEach(Neighborhood.all) { Text($0.name).tag(Optional($0.id)) }
                    } label: { Text("edit.neighborhood") }
                } footer: { Text("edit.language.footer") }
            }
            .navigationTitle(Text("profile.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving { ProgressView() } else {
                        Button("form.save") { Task { await save() } }
                            .bold()
                            .disabled(OnboardingValidator.nameIssue(update.displayName) != nil || update.bio.count > OnboardingValidator.bioLimit)
                    }
                }
            }
            .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("action.ok", role: .cancel) {}
            } message: { Text(error?.message ?? "") }
        }
        .onAppear {
            guard let p = session.profile else { return }
            update = ProfileUpdate(displayName: p.displayName, bio: p.bio, interestIDs: p.interestIDs,
                                   preferredLanguage: p.preferredLanguage, homeNeighborhoodID: p.homeNeighborhoodID)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            var profile = try await env.profiles.updateProfile(update)
            if let photoData { profile = try await env.profiles.uploadAvatar(jpegData: photoData) }
            session.update(profile)
            Haptics.success()
            dismiss()
        } catch {
            self.error = AppError.from(error)
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var preferences = NotificationPreferences()
    @State private var loaded = false

    var body: some View {
        Form {
            if env.push.authorizationStatus == .denied {
                Section {
                    Label("notifications.denied", systemImage: "bell.slash")
                    Button("action.open_settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
            Section {
                Toggle("notifications.join_requests", isOn: $preferences.joinRequests)
                Toggle("notifications.request_updates", isOn: $preferences.requestUpdates)
                Toggle("notifications.reminders", isOn: $preferences.reminders)
                Toggle("notifications.activity_updates", isOn: $preferences.activityUpdates)
                Toggle("notifications.chat", isOn: $preferences.chatMessages)
            } footer: { Text("notifications.safety_footer") }
            Section {
                Toggle("notifications.previews", isOn: $preferences.showMessagePreviews)
            } footer: { Text("notifications.previews.footer") }
        }
        .tint(Theme.Palette.brand)
        .navigationTitle(Text("profile.notifications"))
        .task {
            await env.push.refreshStatus()
            if let stored = try? await env.notificationsRepository.preferences() { preferences = stored }
            loaded = true
        }
        .onChange(of: preferences) { _, newValue in
            guard loaded else { return }
            Task { try? await env.notificationsRepository.updatePreferences(newValue) }
        }
    }
}

struct DeleteAccountView: View {
    @Environment(AppSession.self) private var session
    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var error: AppError?

    private var confirmWord: String { String(localized: "delete.confirm_word") }

    var body: some View {
        Form {
            Section {
                Text("delete.explainer").fixedSize(horizontal: false, vertical: true)
            }
            Section("delete.what_happens") {
                Label("delete.item.profile", systemImage: "person.crop.circle.badge.minus")
                Label("delete.item.activities", systemImage: "calendar.badge.minus")
                Label("delete.item.messages", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                Label("delete.item.reports", systemImage: "doc.text.magnifyingglass")
            }
            Section {
                TextField(text: $confirmText) { Text("delete.type \(confirmWord)") }
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button(role: .destructive) {
                    Task {
                        isDeleting = true
                        do { try await session.deleteAccount() } catch { self.error = AppError.from(error) }
                        isDeleting = false
                    }
                } label: {
                    HStack { Spacer(); if isDeleting { ProgressView() } else { Text("delete.action").bold() }; Spacer() }
                }
                .disabled(confirmText.trimmed.uppercased() != confirmWord.uppercased() || isDeleting)
            }
        }
        .navigationTitle(Text("profile.delete"))
        .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(error?.message ?? "") }
    }
}
