import SwiftUI

struct HostHomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var hosted: LoadState<[Activity]> = .idle
    @State private var showCreate = false
    @State private var showVerification = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("host.title").rvHero(size: 48).foregroundStyle(Theme.Palette.ink).accessibilityAddTraits(.isHeader)
                    Text("host.subtitle").foregroundStyle(Theme.Palette.inkSecondary)
                }
                eligibilityCard
                hostedList
            }
            .padding(Theme.Spacing.screen)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await session.refreshProfile(); await load() }
        .toast($toast)
        .sheet(isPresented: $showCreate) {
            ActivityFormView(mode: .create) { activity in
                showCreate = false
                toast = String(localized: "host.toast.published")
                Task {
                    await load()
                    await env.push.requestAuthorizationIfNeeded()
                    await env.reminders.scheduleReminder(for: activity)
                }
                router.hostPath.append(.manage(activity.id))
            }
        }
        .sheet(isPresented: $showVerification) {
            VerificationView { Task { await session.refreshProfile() } }
        }
    }

    @ViewBuilder private var eligibilityCard: some View {
        switch session.hostingEligibility {
        case .eligible:
            Button { showCreate = true } label: {
                HStack(spacing: Theme.Spacing.l) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.Palette.canvas)
                        .frame(width: 56, height: 56)
                        .background(Theme.Palette.ink, in: Rectangle())
                        .background(Rectangle().fill(Theme.Palette.accent).offset(x: 4, y: 4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("host.create").font(.rvTitle3).foregroundStyle(Theme.Palette.ink)
                        Text("host.create.subtitle").font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    Spacer()
                }
                .rvCard(padding: Theme.Spacing.xl)
                .echoShadow()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("host.create")
        case .needsVerification:
            gateCard(symbol: "checkmark.seal.fill", tint: Theme.Palette.trust, title: "host.gate.verify.title",
                     message: "host.gate.verify.message", action: "host.gate.verify.action") { showVerification = true }
        case .hostingRestricted(let until):
            gateCard(symbol: "pause.circle.fill", tint: Theme.Palette.warning, title: "host.gate.restricted.title",
                     message: until.map { LocalizedStringKey("host.gate.restricted.until \($0.formatted(date: .abbreviated, time: .omitted))") } ?? "host.gate.restricted.message",
                     action: nil, perform: nil)
        case .suspended:
            gateCard(symbol: "exclamationmark.octagon.fill", tint: Theme.Palette.danger, title: "host.gate.suspended.title",
                     message: "host.gate.suspended.message", action: nil, perform: nil)
        case .onboardingIncomplete:
            EmptyView()
        }
    }

    private func gateCard(symbol: String, tint: Color, title: LocalizedStringKey, message: LocalizedStringKey,
                          action: LocalizedStringKey?, perform: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(tint).accessibilityHidden(true)
            Text(title).font(.rvTitle3).foregroundStyle(Theme.Palette.ink)
            Text(message).foregroundStyle(Theme.Palette.inkSecondary).fixedSize(horizontal: false, vertical: true)
            if let action, let perform {
                Button(action, action: perform).buttonStyle(.primary).accessibilityIdentifier("host.verify")
            }
        }
        .rvCard(padding: Theme.Spacing.xl)
    }

    @ViewBuilder private var hostedList: some View {
        switch hosted {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .failed(let error):
            ErrorStateView(error: error) { Task { await load() } }
        case .loaded(let items) where items.isEmpty:
            EmptyView()
        case .loaded(let items):
            let upcoming = items.filter { !$0.hasEnded() && $0.status == .published }
            let past = items.filter { $0.hasEnded() || $0.status != .published }
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeader(title: String(localized: "host.upcoming"))
                    ForEach(upcoming.sorted { $0.startsAt < $1.startsAt }) { activity in
                        NavigationLink(value: Route.manage(activity.id)) { ActivityRow(activity: activity).rvCard(padding: Theme.Spacing.m) }
                            .buttonStyle(.plain)
                    }
                }
            }
            if !past.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeader(title: String(localized: "host.past"))
                    ForEach(past) { activity in
                        NavigationLink(value: Route.manage(activity.id)) { ActivityRow(activity: activity).rvCard(padding: Theme.Spacing.m) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func load() async {
        do { hosted = .loaded(try await env.activities.hostedActivities()) }
        catch { hosted = .failed(AppError.from(error)) }
    }
}

/// Identity verification entry point. Verification confirms identity only; it is not a
/// guarantee of anyone's safety, and the UI says so.
struct VerificationView: View {
    var onChange: () -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var state: VerificationState?
    @State private var isMockProvider = false
    @State private var isWorking = false
    @State private var error: AppError?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(Theme.Palette.trust)
                        .accessibilityHidden(true)
                    Text("verification.title").font(.rvTitle).accessibilityAddTraits(.isHeader)
                    Text("verification.explainer").foregroundStyle(Theme.Palette.inkSecondary)
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        Label("verification.point.documents", systemImage: "lock.fill")
                        Label("verification.point.badge", systemImage: "eye.fill")
                        Label("verification.point.not_guarantee", systemImage: "exclamationmark.shield.fill")
                    }
                    .font(.subheadline)
                    .rvCard()

                    if let state {
                        HStack {
                            Text("verification.status").foregroundStyle(Theme.Palette.inkSecondary)
                            Spacer()
                            StatusPill(text: state.status.title, tint: state.isCurrentlyVerified() ? Theme.Palette.trust : Theme.Palette.ink)
                        }
                        .rvCard()
                    }

                    if isMockProvider || env.config.isMockMode {
                        Label("verification.mock_warning", systemImage: "hammer.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.Palette.warning)
                            .padding(Theme.Spacing.m)
                            .background(Theme.Palette.warningSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }
                    actions
                }
                .padding(Theme.Spacing.screen)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { dismiss() } } }
            .task { state = try? await env.verification.currentState() }
            .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("action.ok", role: .cancel) {}
            } message: { Text(error?.message ?? "") }
        }
    }

    @ViewBuilder private var actions: some View {
        switch state?.status {
        case .verified?:
            if state?.isCurrentlyVerified() == true {
                Button("action.done") { dismiss() }.buttonStyle(.primary)
            } else {
                startButton
            }
        case .pending?:
            if isMockProvider || env.config.isMockMode {
                Button("verification.mock_approve") { Task { await completeMock(true) } }
                    .buttonStyle(.primary).accessibilityIdentifier("verification.mock_approve")
                Button("verification.mock_reject") { Task { await completeMock(false) } }
                    .buttonStyle(.secondary)
            } else {
                Text("verification.pending_message").foregroundStyle(Theme.Palette.inkSecondary)
                Button("verification.refresh") { Task { state = try? await env.verification.currentState(); onChange() } }
                    .buttonStyle(.secondary)
            }
        default:
            startButton
        }
    }

    private var startButton: some View {
        Button {
            Task { await start() }
        } label: {
            if isWorking { ProgressView().tint(Theme.Palette.onBrand) } else { Text("verification.start") }
        }
        .buttonStyle(.primary)
        .disabled(isWorking)
        .accessibilityIdentifier("verification.start")
    }

    private func start() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let start = try await env.verification.startVerification()
            isMockProvider = start.isMockProvider
            if let url = start.url { openURL(url) }
            state = try await env.verification.currentState()
        } catch {
            self.error = AppError.from(error)
        }
    }

    private func completeMock(_ approve: Bool) async {
        do {
            state = try await env.verification.completeMockVerification(approve: approve)
            if approve { Haptics.success() }
            onChange()
        } catch {
            self.error = AppError.from(error)
        }
    }
}
