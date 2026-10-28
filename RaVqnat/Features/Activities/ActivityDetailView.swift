import MapKit
import SwiftUI

struct ActivityDetailView: View {
    let activityID: UUID
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @State private var model: ActivityDetailViewModel?

    var body: some View {
        Group {
            if let model { ActivityDetailContent(model: model) } else { Color.clear }
        }
        .screenBackground()
        .onAppear {
            if model == nil {
                model = ActivityDetailViewModel(activityID: activityID, activities: env.activities,
                                                memberships: env.memberships, safety: env.safety)
            }
        }
    }
}

private struct ActivityDetailContent: View {
    @Bindable var model: ActivityDetailViewModel
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var showJoinSheet = false
    @State private var showGuidelines = false
    @State private var showLeaveConfirm = false
    @State private var showBlockConfirm = false
    @State private var reportTarget: ReportTarget?
    @State private var showFeedback = false
    @State private var checkInEnabled = false

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ErrorStateView(error: error) { Task { await model.load(viewerID: session.userID) } }
            case .loaded(let activity):
                loaded(activity)
            }
        }
        .task { await model.load(viewerID: session.userID) }
        .toast($model.toast)
        .alert(Text("state.error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(model.error?.message ?? "") }
    }

    private func loaded(_ activity: Activity) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ActivityCoverArt(category: activity.category, seed: activity.id, imageURL: activity.coverImageURL)
                    .frame(height: 320)
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    titleBlock(activity)
                    if activity.status == .cancelled { cancelledBanner }
                    hostCard(activity)
                    whenWhere(activity)
                    aboutSection(activity)
                    if !model.participants.isEmpty || activity.isParticipant(session.userID) {
                        participantsSection(activity)
                    }
                    safetySection(activity)
                }
                .padding(Theme.Spacing.screen)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) { actionBar(activity) }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) { topBar(activity) }
        .refreshable { await model.load(viewerID: session.userID) }
        .sheet(isPresented: $showJoinSheet) { JoinRequestSheet(activity: activity) { note in
            showJoinSheet = false
            Task { await join(note: note, activity: activity) }
        } }
        .sheet(isPresented: $showGuidelines) {
            SafetyGuidelinesSheet {
                if let id = session.userID { env.preferences.acknowledgeSafetyGuidelines(id) }
                showGuidelines = false
                showJoinSheet = activity.joinPolicy == .approvalRequired
                if activity.joinPolicy == .open { Task { await join(note: nil, activity: activity) } }
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { showBlockConfirm = true }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet(activity: activity) { model.feedbackSubmitted() }
        }
        .confirmationDialog(Text("detail.leave.title"), isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("detail.leave.action", role: .destructive) {
                Task {
                    if await model.cancelMembership(viewerID: session.userID) { env.reminders.cancel(activityID: activity.id) }
                }
            }
        } message: { Text("detail.leave.message") }
        .blockConfirmation(userName: activity.host.displayName, isPresented: $showBlockConfirm) {
            Task {
                if await model.block(userID: activity.host.id) {
                    env.reminders.cancel(activityID: activity.id)
                    dismiss()
                }
            }
        }
        .onAppear { checkInEnabled = env.preferences.checkInEnabled(activityID: activity.id) }
    }

    private func titleBlock(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                CategoryTag(category: activity.category)
                if activity.isBeginnerFriendly {
                    StatusPill(text: activity.skillLevel.title, symbol: "leaf.fill")
                }
            }
            Text(activity.title).rvHero(size: 28).foregroundStyle(Theme.Palette.ink).accessibilityAddTraits(.isHeader)
        }
    }

    private var cancelledBanner: some View {
        Label("detail.cancelled", systemImage: "xmark.octagon.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Palette.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(Theme.Palette.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private func hostCard(_ activity: Activity) -> some View {
        NavigationLink(value: Route.profile(activity.host.id)) {
            HStack {
                UserRow(user: activity.host, subtitle: activity.isHost(session.userID) ? String(localized: "detail.you_host") : String(localized: "detail.host"), avatarSize: 48)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.inkTertiary)
            }
            .rvCard()
        }
        .buttonStyle(.plain)
        .disabled(activity.isHost(session.userID))
    }

    private func whenWhere(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            InfoRow(symbol: "calendar", title: ActivityTime.fullString(activity.startsAt, timeZoneID: activity.timeZoneID),
                    subtitle: activity.endsAt.map { String(localized: "detail.until \(ActivityTime.timeString($0, timeZoneID: activity.timeZoneID))") })
            InfoRow(symbol: "person.2.fill",
                    title: activity.isFull ? String(localized: "activity.full") : String(localized: "activity.spots_left \(activity.spotsLeft)"),
                    subtitle: String(localized: "activity.approved_count \(activity.approvedCount) \(activity.capacity)"))
            if let details = model.details {
                InfoRow(symbol: "mappin.circle.fill", title: details.venueName, subtitle: details.address)
                if let notes = details.meetingNotes { InfoRow(symbol: "text.bubble", title: notes, subtitle: nil) }
                Map(initialPosition: .region(MKCoordinateRegion(center: details.coordinate.clCoordinate, latitudinalMeters: 800, longitudinalMeters: 800))) {
                    Marker(details.venueName, coordinate: details.coordinate.clCoordinate).tint(activity.category.tint)
                }
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityLabel(Text("detail.map.exact \(details.venueName)"))
            } else {
                InfoRow(symbol: "mappin.and.ellipse", title: activity.neighborhood?.name ?? "",
                        subtitle: String(localized: "detail.location_hidden"))
                Map(initialPosition: .region(MKCoordinateRegion(center: activity.approxCoordinate.clCoordinate, latitudinalMeters: 1600, longitudinalMeters: 1600))) {
                    MapCircle(center: activity.approxCoordinate.clCoordinate, radius: LocationPrivacy.displayRadiusMeters)
                        .foregroundStyle(activity.category.tint.opacity(0.25))
                        .stroke(activity.category.tint, lineWidth: 1.5)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityLabel(Text("detail.map.approx \(activity.neighborhood?.name ?? "")"))
            }
        }
        .rvCard()
    }

    private func aboutSection(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: String(localized: "detail.about"))
            Text(activity.description).foregroundStyle(Theme.Palette.ink).fixedSize(horizontal: false, vertical: true)
            if !activity.isBeginnerFriendly {
                InfoRow(symbol: "chart.bar.fill", title: activity.skillLevel.title, subtitle: String(localized: "detail.skill"))
            }
            if let equipment = activity.equipment {
                InfoRow(symbol: "bag.fill", title: equipment, subtitle: String(localized: "detail.bring"))
            }
            if let instructions = activity.instructions {
                InfoRow(symbol: "info.circle.fill", title: instructions, subtitle: String(localized: "detail.instructions"))
            }
            InfoRow(symbol: activity.joinPolicy == .open ? "door.left.hand.open" : "hand.raised.fill",
                    title: activity.joinPolicy.title, subtitle: nil)
        }
    }

    private func participantsSection(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: String(localized: "detail.going"), trailing: "\(model.participants.count)")
            if model.participants.isEmpty {
                Text("detail.going.empty").font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary)
            }
            ForEach(model.participants) { member in
                NavigationLink(value: Route.profile(member.user.id)) {
                    UserRow(user: member.user)
                }
                .buttonStyle(.plain)
                .disabled(member.user.id == session.userID)
            }
        }
    }

    private func safetySection(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: String(localized: "detail.safety"))
            ShareLink(item: model.shareText()) {
                Label("detail.share_trusted", systemImage: "person.badge.shield.checkmark")
            }
            .buttonStyle(.secondary)
            if activity.myMembership?.occupiesSpot == true && !activity.hasEnded() {
                Toggle(isOn: Binding(get: { checkInEnabled }, set: { enabled in
                    checkInEnabled = enabled
                    env.preferences.setCheckInEnabled(enabled, activityID: activity.id)
                    Task {
                        if enabled {
                            await env.push.requestAuthorizationIfNeeded()
                            await env.reminders.scheduleCheckIn(for: activity)
                        } else {
                            env.reminders.cancelCheckIn(activityID: activity.id)
                        }
                    }
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("detail.checkin").font(.body.weight(.semibold))
                        Text("detail.checkin.subtitle").font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }
                .tint(Theme.Palette.trust)
                .rvCard()
            }
            NavigationLink { EmergencyInfoView() } label: {
                Label("detail.emergency", systemImage: "cross.case.fill").font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.Palette.danger)
        }
    }

    @ViewBuilder private func actionBar(_ activity: Activity) -> some View {
        let state = JoinButtonState(activity: activity, viewerID: session.userID)
        VStack(spacing: Theme.Spacing.s) {
            if model.canLeaveFeedback(viewerID: session.userID) {
                Button { showFeedback = true } label: { Label("detail.feedback", systemImage: "star.bubble") }
                    .buttonStyle(.primary)
            }
            HStack(spacing: Theme.Spacing.s) {
                if activity.isHost(session.userID) {
                    NavigationLink(value: Route.chat(activity.id)) { Label("detail.chat", systemImage: "bubble.left.and.bubble.right.fill") }
                        .buttonStyle(.secondary)
                    NavigationLink(value: Route.manage(activity.id)) { Label("detail.manage", systemImage: "slider.horizontal.3") }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("detail.manage")
                } else if state == .going {
                    NavigationLink(value: Route.chat(activity.id)) { Label("detail.chat", systemImage: "bubble.left.and.bubble.right.fill") }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("detail.chat")
                    if !activity.hasStarted() {
                        Button { showLeaveConfirm = true } label: { Text("detail.leave") }
                            .buttonStyle(.secondary)
                            .frame(maxWidth: 120)
                    }
                } else if state == .requested {
                    Button { showLeaveConfirm = true } label: { Label("detail.withdraw", systemImage: "clock") }
                        .buttonStyle(.secondary)
                        .accessibilityIdentifier("detail.requested")
                } else {
                    Button { startJoin(activity) } label: {
                        if model.isWorking { ProgressView().tint(Theme.Palette.onBrand) } else { Text(state.title) }
                    }
                    .buttonStyle(.primary)
                    .disabled(!state.isActionable || model.isWorking)
                    .accessibilityIdentifier("detail.join")
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .overlay(alignment: .top) { Divider().overlay(Theme.Palette.hairline) }
    }

    /// Floating round buttons over the cover, replacing the system navigation bar.
    private func topBar(_ activity: Activity) -> some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.iconOnMedia)
                .accessibilityLabel(Text("action.back"))
                .accessibilityIdentifier("detail.back")
            Spacer()
            ShareLink(item: model.shareText()) { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(.iconOnMedia)
                .accessibilityLabel(Text("detail.share_trusted"))
            if !activity.isHost(session.userID) {
                Menu {
                    Button {
                        reportTarget = ReportTarget(userID: activity.host.id, userName: activity.host.displayName, activityID: activity.id)
                    } label: { Label("detail.report", systemImage: "flag") }
                    Button(role: .destructive) { showBlockConfirm = true } label: {
                        Label("detail.block_host", systemImage: "hand.raised.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .frame(width: 40, height: 40)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel(Text("detail.more"))
                .accessibilityIdentifier("detail.more")
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.xs)
    }

    private func startJoin(_ activity: Activity) {
        guard let userID = session.userID else { return }
        if !env.preferences.hasAcknowledgedSafetyGuidelines(userID) {
            showGuidelines = true
        } else if activity.joinPolicy == .approvalRequired {
            showJoinSheet = true
        } else {
            Task { await join(note: nil, activity: activity) }
        }
    }

    private func join(note: String?, activity: Activity) async {
        if let state = await model.requestJoin(note: note, viewerID: session.userID) {
            await env.push.requestAuthorizationIfNeeded()
            if state.occupiesSpot, let refreshed = model.activity { await env.reminders.scheduleReminder(for: refreshed) }
        }
    }
}

struct InfoRow: View {
    let symbol: String
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.brand)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.Palette.ink).fixedSize(horizontal: false, vertical: true)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(Theme.Palette.inkSecondary) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Optional note to the host; sending takes one tap.
struct JoinRequestSheet: View {
    let activity: Activity
    let onSend: (String?) -> Void
    @State private var note = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("join.sheet.subtitle \(activity.host.displayName)").foregroundStyle(Theme.Palette.inkSecondary)
                TextField(text: $note, axis: .vertical) { Text("join.sheet.placeholder") }
                    .lineLimit(2...4)
                    .padding(Theme.Spacing.m)
                    .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .accessibilityIdentifier("join.note")
                Button("join.sheet.send") { onSend(note.nilIfBlank.map { String($0.prefix(280)) }) }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("join.send")
                Spacer()
            }
            .padding(Theme.Spacing.screen)
            .navigationTitle(Text("join.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
