import SwiftUI

struct ReportTarget: Identifiable, Hashable {
    var id: String { "\(userID)-\(activityID?.uuidString ?? "")-\(messageID?.uuidString ?? "")" }
    let userID: UUID
    let userName: String
    var activityID: UUID?
    var messageID: UUID?
    var storyID: UUID?
}

/// Private report form. The reported person is never told who reported them.
struct ReportSheet: View {
    let target: ReportTarget
    var onBlockRequested: (() -> Void)?
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReportDraft
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var error: AppError?

    init(target: ReportTarget, onBlockRequested: (() -> Void)? = nil) {
        self.target = target
        self.onBlockRequested = onBlockRequested
        _draft = State(initialValue: ReportDraft(reportedUserID: target.userID, activityID: target.activityID,
                                                 messageID: target.messageID, storyID: target.storyID))
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted { confirmation } else { form }
            }
            .navigationTitle(Text("report.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(submitted ? "action.done" : "action.cancel") { dismiss() } }
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                Text("report.intro \(target.userName)").foregroundStyle(Theme.Palette.inkSecondary)
            }
            Section("report.category") {
                ForEach(ReportCategory.allCases) { category in
                    Button { draft.category = category } label: {
                        HStack {
                            Text(category.title).foregroundStyle(Theme.Palette.ink)
                            Spacer()
                            if draft.category == category { Image(systemName: "checkmark").foregroundStyle(Theme.Palette.brand) }
                        }
                    }
                    .accessibilityAddTraits(draft.category == category ? .isSelected : [])
                    .accessibilityIdentifier("report.category.\(category.rawValue)")
                }
            }
            Section {
                TextField(text: $draft.description, axis: .vertical) { Text("report.description.placeholder") }
                    .lineLimit(4...8)
            } header: { Text("report.description") } footer: {
                Text("report.privacy_note")
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack { Spacer(); if isSubmitting { ProgressView() } else { Text("report.submit").bold() }; Spacer() }
                }
                .disabled(draft.category == nil || isSubmitting || draft.description.count > ReportDraft.maxDescriptionLength)
                .accessibilityIdentifier("report.submit")
            }
        }
        .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(error?.message ?? "") }
    }

    private var confirmation: some View {
        VStack(spacing: Theme.Spacing.l) {
            EmptyStateView(symbol: "checkmark.shield.fill", title: String(localized: "report.done.title"),
                           message: String(localized: "report.done.message"))
            if let onBlockRequested {
                Button {
                    dismiss()
                    onBlockRequested()
                } label: { Label("report.done.block \(target.userName)", systemImage: "hand.raised.slash") }
                .buttonStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.screen)
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await env.safety.submitReport(draft)
            Haptics.success()
            submitted = true
        } catch {
            self.error = AppError.from(error)
        }
    }
}

extension View {
    /// Confirmation dialog explaining what blocking does before calling `onConfirm`.
    func blockConfirmation(userName: String?, isPresented: Binding<Bool>, onConfirm: @escaping () -> Void) -> some View {
        confirmationDialog(Text("block.confirm.title \(userName ?? "")"), isPresented: isPresented, titleVisibility: .visible) {
            Button("block.confirm.action", role: .destructive, action: onConfirm)
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("block.confirm.message")
        }
    }
}
