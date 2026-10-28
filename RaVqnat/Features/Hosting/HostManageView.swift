import SwiftUI

@MainActor
@Observable
final class HostManageViewModel {
    let activityID: UUID
    private(set) var activity: Activity?
    private(set) var details: ActivityPrivateDetails?
    private(set) var members: LoadState<[Member]> = .idle
    private(set) var busyUserIDs: Set<UUID> = []
    var error: AppError?
    var toast: String?

    private let activities: any ActivityRepository
    private let memberships: any MembershipRepository

    init(activityID: UUID, activities: any ActivityRepository, memberships: any MembershipRepository) {
        self.activityID = activityID
        self.activities = activities
        self.memberships = memberships
    }

    var pending: [Member] { members.value?.filter { $0.state == .pending } ?? [] }
    var going: [Member] { members.value?.filter { $0.state.occupiesSpot || $0.state == .noShow } ?? [] }

    func load() async {
        if members.value == nil { members = .loading }
        do {
            async let activity = activities.activity(id: activityID)
            async let details = activities.privateDetails(activityID: activityID)
            async let members = memberships.members(activityID: activityID)
            self.activity = try await activity
            self.details = try await details
            self.members = .loaded(try await members)
        } catch {
            if members.value == nil { members = .failed(AppError.from(error)) } else { self.error = AppError.from(error) }
        }
    }

    enum Decision { case approve, reject, remove, attended, noShow }

    func decide(_ decision: Decision, member: Member) async {
        busyUserIDs.insert(member.id)
        defer { busyUserIDs.remove(member.id) }
        do {
            switch decision {
            case .approve: try await memberships.approve(activityID: activityID, userID: member.id)
            case .reject: try await memberships.reject(activityID: activityID, userID: member.id)
            case .remove: try await memberships.remove(activityID: activityID, userID: member.id)
            case .attended: try await memberships.markAttendance(activityID: activityID, userID: member.id, attended: true)
            case .noShow: try await memberships.markAttendance(activityID: activityID, userID: member.id, attended: false)
            }
            Haptics.success()
        } catch {
            self.error = AppError.from(error)
            Haptics.error()
        }
        await load()
    }

    func cancelActivity(reason: String) async -> Bool {
        do {
            try await activities.cancelActivity(id: activityID, reason: reason)
            toast = String(localized: "manage.toast.cancelled")
            await load()
            return true
        } catch {
            self.error = AppError.from(error)
            return false
        }
    }
}

struct HostManageView: View {
    let activityID: UUID
    @Environment(AppEnvironment.self) private var env
    @State private var model: HostManageViewModel?

    var body: some View {
        Group {
            if let model { HostManageContent(model: model) } else { Color.clear }
        }
        .screenBackground()
        .onAppear {
            if model == nil { model = HostManageViewModel(activityID: activityID, activities: env.activities, memberships: env.memberships) }
        }
    }
}

private struct HostManageContent: View {
    @Bindable var model: HostManageViewModel
    @Environment(AppEnvironment.self) private var env
    @State private var showEdit = false
    @State private var showCancel = false
    @State private var cancelReason = ""
    @State private var removing: Member?
    @State private var reportTarget: ReportTarget?

    var body: some View {
        List {
            if let activity = model.activity {
                Section {
                    NavigationLink(value: Route.activity(activity.id)) { ActivityRow(activity: activity, showStatus: true) }
                    if activity.status == .published {
                        NavigationLink(value: Route.chat(activity.id)) { Label("detail.chat", systemImage: "bubble.left.and.bubble.right") }
                    }
                }
                requestsSection(activity)
                goingSection(activity)
                if activity.status == .published && !activity.hasStarted() {
                    Section {
                        Button { showEdit = true } label: { Label("manage.edit", systemImage: "pencil") }
                        Button(role: .destructive) { showCancel = true } label: { Label("manage.cancel", systemImage: "xmark.circle") }
                    } footer: { Text("manage.cancel.footer") }
                }
            } else if case .failed(let error) = model.members {
                ErrorStateView(error: error) { Task { await model.load() } }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(Text("manage.title"))
        .task { await model.load() }
        .refreshable { await model.load() }
        .toast($model.toast)
        .sheet(isPresented: $showEdit) {
            if let activity = model.activity {
                ActivityFormView(mode: .edit(activity, model.details)) { _ in
                    showEdit = false
                    model.toast = String(localized: "manage.toast.saved")
                    Task { await model.load() }
                }
            }
        }
        .sheet(item: $reportTarget) { ReportSheet(target: $0) }
        .alert(Text("manage.cancel.title"), isPresented: $showCancel) {
            TextField(text: $cancelReason) { Text("manage.cancel.reason") }
            Button("manage.cancel.confirm", role: .destructive) {
                Task {
                    if await model.cancelActivity(reason: cancelReason) { env.reminders.cancel(activityID: model.activityID) }
                }
            }
            Button("action.back", role: .cancel) {}
        } message: { Text("manage.cancel.message") }
        .confirmationDialog(Text("manage.remove.title \(removing?.user.displayName ?? "")"), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("manage.remove.confirm", role: .destructive) {
                if let member = removing { Task { await model.decide(.remove, member: member) } }
            }
        }
        .alert(Text("state.error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(model.error?.message ?? "") }
    }

    @ViewBuilder private func requestsSection(_ activity: Activity) -> some View {
        Section {
            if model.pending.isEmpty {
                Text("manage.requests.empty").foregroundStyle(Theme.Palette.inkSecondary)
            }
            ForEach(model.pending) { member in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    NavigationLink(value: Route.profile(member.id)) {
                        UserRow(user: member.user, subtitle: member.requestedAt.formatted(.relative(presentation: .named)))
                    }
                    if let note = member.note {
                        Text("“\(note)”").font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    HStack {
                        Button { Task { await model.decide(.approve, member: member) } } label: { Text("manage.approve") }
                            .buttonStyle(PillButtonStyle(tint: Theme.Palette.success))
                            .disabled(activity.isFull || model.busyUserIDs.contains(member.id))
                            .accessibilityIdentifier("manage.approve.\(member.user.displayName)")
                        Button { Task { await model.decide(.reject, member: member) } } label: { Text("manage.decline") }
                            .buttonStyle(PillButtonStyle(tint: Theme.Palette.inkSecondary, filled: false))
                            .disabled(model.busyUserIDs.contains(member.id))
                        Spacer()
                        if model.busyUserIDs.contains(member.id) { ProgressView() }
                    }
                }
                .padding(.vertical, 4)
                .contextMenu { reportButton(member) }
            }
        } header: {
            Text("manage.requests \(model.pending.count)")
        } footer: {
            if activity.isFull && !model.pending.isEmpty { Text("manage.full_footer") }
        }
    }

    @ViewBuilder private func goingSection(_ activity: Activity) -> some View {
        Section {
            if model.going.isEmpty {
                Text("manage.going.empty").foregroundStyle(Theme.Palette.inkSecondary)
            }
            ForEach(model.going) { member in
                HStack {
                    NavigationLink(value: Route.profile(member.id)) {
                        UserRow(user: member.user, subtitle: activity.hasStarted() ? member.state.title : nil)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !activity.hasStarted() && member.state == .approved {
                        Button(role: .destructive) { removing = member } label: { Label("manage.remove", systemImage: "person.fill.xmark") }
                    }
                }
                .contextMenu {
                    if activity.hasStarted() {
                        Button { Task { await model.decide(.attended, member: member) } } label: { Label("manage.mark_attended", systemImage: "checkmark.circle") }
                        Button { Task { await model.decide(.noShow, member: member) } } label: { Label("manage.mark_no_show", systemImage: "questionmark.circle") }
                    } else if member.state == .approved {
                        Button(role: .destructive) { removing = member } label: { Label("manage.remove", systemImage: "person.fill.xmark") }
                    }
                    reportButton(member)
                }
            }
        } header: {
            Text("manage.going \(activity.approvedCount) \(activity.capacity)")
        } footer: {
            Text(activity.hasStarted() ? "manage.going.footer_started" : "manage.going.footer")
        }
    }

    private func reportButton(_ member: Member) -> some View {
        Button { reportTarget = ReportTarget(userID: member.id, userName: member.user.displayName, activityID: model.activityID) } label: {
            Label("detail.report", systemImage: "flag")
        }
    }
}
