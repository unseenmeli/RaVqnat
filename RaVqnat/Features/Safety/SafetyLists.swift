import SwiftUI

struct BlockedUsersView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var state: LoadState<[BlockedUser]> = .idle
    @State private var error: AppError?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error): ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let users) where users.isEmpty:
                EmptyStateView(symbol: "person.crop.circle.badge.checkmark", title: String(localized: "blocked.empty.title"),
                               message: String(localized: "blocked.empty.message"))
            case .loaded(let users):
                List(users) { blocked in
                    HStack {
                        UserRow(user: blocked.user, subtitle: String(localized: "blocked.since \(blocked.blockedAt.formatted(date: .abbreviated, time: .omitted))"))
                        Spacer()
                        Button("blocked.unblock") { Task { await unblock(blocked.user.id) } }
                            .buttonStyle(.secondaryCompact)
                    }
                }
            }
        }
        .screenBackground()
        .navigationTitle(Text("safety.center.blocked"))
        .task { await load() }
        .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(error?.message ?? "") }
    }

    private func load() async {
        do { state = .loaded(try await env.safety.blockedUsers()) } catch { state = .failed(AppError.from(error)) }
    }

    private func unblock(_ id: UUID) async {
        do { try await env.safety.unblock(userID: id); await load() } catch { self.error = AppError.from(error) }
    }
}

struct ReportHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var state: LoadState<[ReportRecord]> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error): ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let reports) where reports.isEmpty:
                EmptyStateView(symbol: "flag", title: String(localized: "reports.empty.title"), message: String(localized: "reports.empty.message"))
            case .loaded(let reports):
                List(reports) { report in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(report.category.title).font(.body.weight(.semibold))
                            Spacer()
                            StatusPill(text: report.status.title)
                        }
                        Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .screenBackground()
        .navigationTitle(Text("safety.center.reports"))
        .task { await load() }
    }

    private func load() async {
        do { state = .loaded(try await env.safety.myReports()) } catch { state = .failed(AppError.from(error)) }
    }
}

/// Private post-activity feedback. Never shown to the person it is about.
struct FeedbackSheet: View {
    let activity: Activity
    var onSubmitted: () -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var draft: FeedbackDraft
    @State private var isSubmitting = false
    @State private var error: AppError?

    init(activity: Activity, onSubmitted: @escaping () -> Void) {
        self.activity = activity
        self.onSubmitted = onSubmitted
        _draft = State(initialValue: FeedbackDraft(activityID: activity.id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("feedback.intro \(activity.title)").foregroundStyle(Theme.Palette.inkSecondary)
                }
                Section("feedback.rating") {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(1...5, id: \.self) { value in
                            Button { draft.rating = value } label: {
                                Image(systemName: value <= draft.rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(value <= draft.rating ? Theme.Palette.warning : Theme.Palette.inkTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("feedback.stars \(value)"))
                            .accessibilityAddTraits(value == draft.rating ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .sensoryFeedback(.selection, trigger: draft.rating)
                }
                Section("feedback.felt_safe") {
                    Picker(selection: $draft.feltSafe) {
                        Text("feedback.yes").tag(Bool?.some(true))
                        Text("feedback.no").tag(Bool?.some(false))
                        Text("feedback.skip").tag(Bool?.none)
                    } label: { Text("feedback.felt_safe") }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section {
                    TextField(text: $draft.comment, axis: .vertical) { Text("feedback.comment.placeholder") }
                        .lineLimit(3...6)
                } footer: { Text("feedback.privacy") }
            }
            .navigationTitle(Text("feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("feedback.send") { Task { await submit() } }
                        .bold()
                        .disabled(draft.rating == 0 || isSubmitting)
                }
            }
            .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("action.ok", role: .cancel) {}
            } message: { Text(error?.message ?? "") }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await env.safety.submitFeedback(draft)
            Haptics.success()
            onSubmitted()
            dismiss()
        } catch {
            self.error = AppError.from(error)
        }
    }
}
