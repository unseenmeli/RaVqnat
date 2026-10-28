import PhotosUI
import SwiftUI

/// Post a photo or a short text card to an activity you host or are approved for.
struct StoryComposer: View {
    let onPosted: () -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var draft = StoryDraft()
    @State private var eligible: LoadState<[Activity]> = .idle
    @State private var photoItem: PhotosPickerItem?
    @State private var isPosting = false
    @State private var error: AppError?

    var body: some View {
        NavigationStack {
            Group {
                switch eligible {
                case .idle, .loading: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let error): ErrorStateView(error: error) { Task { await load() } }
                case .loaded(let activities) where activities.isEmpty:
                    EmptyStateView(symbol: "circle.dashed", title: String(localized: "stories.compose.none.title"),
                                   message: String(localized: "stories.compose.none.message"))
                case .loaded(let activities): composer(activities)
                }
            }
            .navigationTitle(Text("stories.compose.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting { ProgressView() } else {
                        Button("stories.compose.share") { Task { await post() } }
                            .bold()
                            .disabled(!draft.isValid)
                            .accessibilityIdentifier("stories.share")
                    }
                }
            }
            .task { await load() }
            .alert(Text("state.error.title"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("action.ok", role: .cancel) {}
            } message: { Text(error?.message ?? "") }
        }
    }

    private func composer(_ activities: [Activity]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Picker(selection: $draft.kind) {
                    Text("stories.compose.text").tag(StoryKind.text)
                    Text("stories.compose.photo").tag(StoryKind.photo)
                } label: { EmptyView() }
                .pickerStyle(.segmented)

                preview
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                if draft.kind == .text {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(StoryBackground.allCases) { background in
                            Button { draft.background = background } label: {
                                Circle().fill(background.color).frame(width: 32, height: 32)
                                    .overlay(Circle().strokeBorder(Theme.Palette.hairline))
                                    .padding(3)
                                    .overlay(Circle().strokeBorder(draft.background == background ? Theme.Palette.ink : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: background.rawValue))
                            .accessibilityAddTraits(draft.background == background ? .isSelected : [])
                        }
                    }
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(draft.imageData == nil ? "photo.choose" : "photo.change", systemImage: "photo")
                    }
                    .buttonStyle(.secondaryCompact)
                }

                TextField(text: $draft.text, axis: .vertical) {
                    Text(draft.kind == .text ? "stories.compose.text_placeholder" : "stories.compose.caption_placeholder")
                }
                .lineLimit(2...4)
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .accessibilityIdentifier("stories.text")
                Text(verbatim: "\(draft.text.count)/\(Story.maxTextLength)")
                    .font(.caption)
                    .foregroundStyle(draft.text.count > Story.maxTextLength ? Theme.Palette.danger : Theme.Palette.inkTertiary)

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("stories.compose.activity").font(.headline)
                    ForEach(activities) { activity in
                        Button { draft.activityID = activity.id } label: {
                            HStack {
                                ActivityRow(activity: activity, showStatus: false)
                                Image(systemName: draft.activityID == activity.id ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(draft.activityID == activity.id ? Theme.Palette.ink : Theme.Palette.surfaceStrong)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(draft.activityID == activity.id ? .isSelected : [])
                    }
                }
                Text("stories.compose.footer").font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
            }
            .padding(Theme.Spacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self) {
                    draft.imageData = ImageProcessing.preparedJPEG(from: raw, maxDimension: 1600)
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if draft.kind == .photo, let data = draft.imageData, let image = UIImage(data: data) {
            ZStack(alignment: .bottom) {
                Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                if !draft.text.isEmpty {
                    Text(draft.text).font(.title3.weight(.semibold)).foregroundStyle(.white)
                        .padding(Theme.Spacing.m).background(Capsule().fill(.black.opacity(0.55))).padding(Theme.Spacing.l)
                }
            }
        } else if draft.kind == .photo {
            ZStack {
                Theme.Palette.surfaceMuted
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(Theme.Palette.inkTertiary)
            }
        } else {
            ZStack {
                draft.background.color
                Text(draft.text.isEmpty ? String(localized: "stories.compose.preview") : draft.text)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(draft.background.foreground.opacity(draft.text.isEmpty ? 0.5 : 1))
                    .padding(Theme.Spacing.xl)
            }
        }
    }

    private func load() async {
        do {
            let activities = try await env.stories.storyEligibleActivities()
            eligible = .loaded(activities)
            if draft.activityID == nil { draft.activityID = activities.first?.id }
        } catch {
            eligible = .failed(AppError.from(error))
        }
    }

    private func post() async {
        isPosting = true
        defer { isPosting = false }
        do {
            _ = try await env.stories.postStory(draft)
            Haptics.success()
            onPosted()
            dismiss()
        } catch {
            self.error = AppError.from(error)
        }
    }
}
