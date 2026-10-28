import SwiftUI

/// Full-screen story viewer: segmented progress, tap right/left to move, hold to pause,
/// swipe down to close. Advances to the next activity's stories at the end of a group.
struct StoryViewer: View {
    let groups: [StoryGroup]
    let startGroup: Int
    let viewerID: UUID?
    let onSeen: (Story) -> Void
    let onDelete: (Story) -> Void
    let onOpenActivity: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var groupIndex = 0
    @State private var storyIndex = 0
    @State private var progress: Double = 0
    @State private var isPaused = false
    @State private var dragOffset: CGFloat = 0
    @State private var reportTarget: ReportTarget?
    @State private var blocking: UserSummary?
    @Environment(AppEnvironment.self) private var env

    static let duration: Double = 5

    private var group: StoryGroup? { groups.indices.contains(groupIndex) ? groups[groupIndex] : nil }
    private var story: Story? { group.flatMap { $0.stories.indices.contains(storyIndex) ? $0.stories[storyIndex] : nil } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let group, let story {
                StoryCanvas(story: story)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { tapZones }
                    .overlay(alignment: .top) { header(group: group, story: story) }
                    .overlay(alignment: .bottom) { footer(group: group, story: story) }
                    .id(story.id)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .offset(y: max(0, dragOffset))
        .scaleEffect(1 - min(0.15, max(0, dragOffset) / 2000))
        .gesture(DragGesture(minimumDistance: 20)
            .onChanged { value in dragOffset = value.translation.height; isPaused = true }
            .onEnded { value in
                if value.translation.height > 120 { dismiss() } else {
                    withAnimation(.spring(duration: 0.25)) { dragOffset = 0 }
                    isPaused = false
                }
            })
        .statusBarHidden()
        .task(id: "\(groupIndex)-\(storyIndex)") { await play() }
        .onAppear {
            groupIndex = startGroup
            storyIndex = groups.indices.contains(startGroup) ? groups[startGroup].firstUnseenIndex : 0
        }
        .sheet(item: $reportTarget, onDismiss: { isPaused = false }) { target in
            ReportSheet(target: target) { if let story { blocking = story.author } }
        }
        .blockConfirmation(userName: blocking?.displayName,
                           isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil; isPaused = false } })) {
            if let user = blocking {
                Task { try? await env.safety.block(userID: user.id); dismiss() }
            }
        }
        .accessibilityAction(.escape) { dismiss() }
    }

    // MARK: Playback

    private func play() async {
        guard let story else { return }
        onSeen(story)
        progress = 0
        let tick = 0.05
        while progress < 1 {
            try? await Task.sleep(for: .seconds(tick))
            if Task.isCancelled { return }
            if !isPaused { progress += tick / Self.duration }
        }
        advance()
    }

    private func advance() {
        guard let group else { return dismiss() }
        if storyIndex + 1 < group.stories.count {
            storyIndex += 1
        } else if groupIndex + 1 < groups.count {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                groupIndex += 1
                storyIndex = 0
            }
        } else {
            dismiss()
        }
    }

    private func goBack() {
        if storyIndex > 0 {
            storyIndex -= 1
        } else if groupIndex > 0 {
            groupIndex -= 1
            storyIndex = max(0, groups[groupIndex].stories.count - 1)
        } else {
            progress = 0
        }
    }

    // MARK: Chrome

    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle()).onTapGesture(perform: goBack)
                .accessibilityLabel(Text("stories.previous")).accessibilityAddTraits(.isButton)
            Color.clear.contentShape(Rectangle()).onTapGesture(perform: advance)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("stories.next")).accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("stories.next")
        }
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.2).onEnded { _ in isPaused = true })
        .onLongPressGesture(minimumDuration: 0.2, perform: {}, onPressingChanged: { pressing in isPaused = pressing })
    }

    private func header(group: StoryGroup, story: Story) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: 3) {
                ForEach(group.stories.indices, id: \.self) { index in
                    GeometryReader { proxy in
                        Capsule().fill(.white.opacity(0.35))
                            .overlay(alignment: .leading) {
                                Capsule().fill(.white)
                                    .frame(width: proxy.size.width * (index < storyIndex ? 1 : index == storyIndex ? progress : 0))
                            }
                    }
                    .frame(height: 2.5)
                }
            }
            HStack(spacing: Theme.Spacing.s) {
                AvatarView(name: story.author.displayName, url: story.author.avatarURL, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(story.author.displayName).font(.subheadline.weight(.semibold))
                        if story.author.isVerified { VerifiedBadge(size: .caption) }
                        Text(story.createdAt.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))
                            .font(.subheadline).opacity(0.7)
                    }
                    Text(group.activityTitle).font(.caption).opacity(0.8).lineLimit(1)
                }
                Spacer()
                Menu {
                    if story.author.id == viewerID || group.host.id == viewerID {
                        Button(role: .destructive) { onDelete(story); dismiss() } label: { Label("stories.delete", systemImage: "trash") }
                    }
                    if story.author.id != viewerID {
                        Button {
                            isPaused = true
                            reportTarget = ReportTarget(userID: story.author.id, userName: story.author.displayName,
                                                        activityID: story.activityID, storyID: story.id)
                        } label: { Label("stories.report", systemImage: "flag") }
                        Button(role: .destructive) { isPaused = true; blocking = story.author } label: {
                            Label("chat.block \(story.author.displayName)", systemImage: "hand.raised.slash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.headline).frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .accessibilityLabel(Text("detail.more"))
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).frame(width: 36, height: 36).contentShape(Rectangle())
                }
                .accessibilityLabel(Text("action.close"))
                .accessibilityIdentifier("stories.close")
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
        .background(LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom).allowsHitTesting(false))
    }

    private func footer(group: StoryGroup, story: Story) -> some View {
        Button {
            dismiss()
            onOpenActivity(group.activityID)
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: group.category.symbol)
                Text("stories.view_activity")
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, Theme.Spacing.l)
            .frame(height: 44)
            .background(.white, in: Capsule())
        }
        .padding(.bottom, Theme.Spacing.xl)
        .accessibilityIdentifier("stories.view_activity")
    }
}

/// Renders one story: a photo, or text on a flat background.
struct StoryCanvas: View {
    let story: Story

    var body: some View {
        ZStack {
            story.background.color
            if story.kind == .photo, let url = story.mediaURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { ProgressView().tint(.white) }
                }
            }
            if let text = story.text {
                Text(text)
                    .font(story.kind == .text ? .system(size: 30, weight: .bold) : .title3.weight(.semibold))
                    .tracking(-0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(story.background.foreground)
                    .padding(story.kind == .text ? Theme.Spacing.xl : Theme.Spacing.m)
                    .background {
                        if story.kind == .photo { Capsule().fill(.black.opacity(0.55)) }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .frame(maxHeight: .infinity, alignment: story.kind == .photo ? .bottom : .center)
                    .padding(.bottom, story.kind == .photo ? 110 : 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension StoryBackground {
    var color: Color {
        switch self {
        case .ink: Color(light: 0x0A0A0A, dark: 0x0A0A0A)
        case .mist: Color(light: 0xE9E9EC, dark: 0xE9E9EC)
        case .pink: Color(light: 0xFF2E9A, dark: 0xFF2E9A)
        case .sky: Color(light: 0x3B82F6, dark: 0x3B82F6)
        case .sage: Color(light: 0x5F8F6E, dark: 0x5F8F6E)
        }
    }

    var foreground: Color { self == .mist ? .black : .white }
}
