import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @State private var hosted: [Activity] = []
    @State private var joined: [Activity] = []
    @State private var showEdit = false
    @State private var showVerification = false

    var body: some View {
        List {
            if let profile = session.profile {
                Section { header(profile) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                activitiesSection(title: "profile.joined", items: joined, empty: "profile.joined.empty")
                activitiesSection(title: "profile.hosted", items: hosted, empty: "profile.hosted.empty")

                Section("profile.section.account") {
                    Button { showEdit = true } label: { Label("profile.edit", systemImage: "pencil") }
                    Button { showVerification = true } label: {
                        HStack {
                            Label("profile.verification", systemImage: "checkmark.seal")
                            Spacer()
                            Text(profile.verification.isCurrentlyVerified() ? VerificationStatus.verified.title : profile.verification.status.title)
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                    NavigationLink { NotificationSettingsView() } label: { Label("profile.notifications", systemImage: "bell") }
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
                }
                .foregroundStyle(Theme.Palette.ink)

                Section("profile.section.safety") {
                    NavigationLink(value: Route.safetyCenter) { Label("safety.center.title", systemImage: "shield.lefthalf.filled") }
                }

                Section {
                    Button("profile.sign_out") { Task { await session.signOut() } }
                    NavigationLink { DeleteAccountView() } label: { Text("profile.delete").foregroundStyle(Theme.Palette.danger) }
                } footer: {
                    Text(verbatim: "RaVqnat \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")\(env.config.isMockMode ? " · demo" : "")")
                }
            }
        }
        .navigationTitle(Text("tab.profile"))
        .task { await load() }
        .refreshable { await session.refreshProfile(); await load() }
        .sheet(isPresented: $showEdit) { EditProfileView() }
        .sheet(isPresented: $showVerification) { VerificationView { Task { await session.refreshProfile() } } }
    }

    private func header(_ profile: MyProfile) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            AvatarView(name: profile.displayName, url: profile.avatarURL, size: 96)
            HStack(spacing: 6) {
                Text(profile.displayName).font(.rvTitle).foregroundStyle(Theme.Palette.ink)
                if profile.isVerified { VerifiedBadge(size: .title3) }
            }
            if !profile.bio.isEmpty {
                Text(profile.bio).font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary).multilineTextAlignment(.center)
            }
            if let hood = Neighborhood.find(profile.homeNeighborhoodID) {
                Label(hood.name, systemImage: "mappin").font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
            }
            FlowLayout(spacing: 6) {
                ForEach(profile.interestIDs.compactMap(Interest.find)) { interest in
                    StatusPill(text: interest.title, symbol: interest.category.symbol, tint: interest.category.tint, background: interest.category.softTint)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
    }

    @ViewBuilder
    private func activitiesSection(title: LocalizedStringKey, items: [Activity], empty: LocalizedStringKey) -> some View {
        Section(title) {
            if items.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary)
            }
            ForEach(items.prefix(5)) { activity in
                NavigationLink(value: Route.activity(activity.id)) { ActivityRow(activity: activity) }
            }
        }
    }

    private func load() async {
        async let hosted = env.activities.hostedActivities()
        async let joined = env.activities.joinedActivities()
        self.hosted = (try? await hosted) ?? []
        self.joined = (try? await joined) ?? []
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

/// Another person's profile. Shows only public information — never contact details.
struct PublicProfileView: View {
    let userID: UUID
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState<PublicProfile> = .idle
    @State private var upcoming: [Activity] = []
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
                AvatarView(name: profile.displayName, url: profile.avatarURL, size: 104)
                HStack(spacing: 6) {
                    Text(profile.displayName).font(.rvTitle)
                    if profile.isVerified { VerifiedBadge(size: .title3) }
                }
                if profile.isVerified {
                    Text("profile.verified_note").font(.footnote).foregroundStyle(Theme.Palette.inkSecondary).multilineTextAlignment(.center)
                }
                if !profile.bio.isEmpty { Text(profile.bio).multilineTextAlignment(.center).foregroundStyle(Theme.Palette.ink) }
                HStack(spacing: Theme.Spacing.xl) {
                    stat("\(profile.hostedActivityCount)", "profile.stat.hosted")
                    stat(profile.memberSince.formatted(.dateTime.month(.abbreviated).year()), "profile.stat.member_since")
                }
                FlowLayout(spacing: 6) {
                    ForEach(profile.interestIDs.compactMap(Interest.find)) { interest in
                        StatusPill(text: interest.title, symbol: interest.category.symbol, tint: interest.category.tint, background: interest.category.softTint)
                    }
                }
                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        SectionHeader(title: String(localized: "profile.upcoming_hosted"))
                        ForEach(upcoming) { activity in
                            NavigationLink(value: Route.activity(activity.id)) { ActivityRow(activity: activity).rvCard(padding: Theme.Spacing.m) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.screen)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { reportTarget = ReportTarget(userID: profile.id, userName: profile.displayName) } label: {
                        Label("detail.report", systemImage: "flag")
                    }
                    Button(role: .destructive) { showBlock = true } label: { Label("profile.block", systemImage: "hand.raised.slash") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel(Text("detail.more"))
            }
        }
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.rvHeadline).foregroundStyle(Theme.Palette.ink)
            Text(label).font(.caption).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .accessibilityElement(children: .combine)
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
