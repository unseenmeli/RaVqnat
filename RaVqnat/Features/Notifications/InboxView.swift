import SwiftUI

struct InboxView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var state: LoadState<[InboxItem]> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let items) where items.isEmpty:
                EmptyStateView(symbol: "bell", title: String(localized: "inbox.empty.title"),
                               message: String(localized: "inbox.empty.message"))
            case .loaded(let items):
                List {
                    let fresh = items.filter { !$0.isRead }
                    let earlier = items.filter(\.isRead)
                    if !fresh.isEmpty {
                        Section("inbox.new") { ForEach(fresh) { row($0) } }
                    }
                    if !earlier.isEmpty {
                        Section("inbox.earlier") { ForEach(earlier) { row($0) } }
                    }
                }
                .listStyle(.plain)
            }
        }
        .screenBackground()
        .navigationTitle(Text("inbox.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
            // Keep the "New" grouping for this visit; the badge clears for next time.
            try? await env.inbox.markAllRead()
        }
        .refreshable { await load() }
    }

    @ViewBuilder private func row(_ item: InboxItem) -> some View {
        let content = InboxRow(item: item)
        if let route = item.route {
            NavigationLink(value: route) { content }
        } else {
            content
        }
    }

    private func load() async {
        if state.value == nil { state = .loading }
        do { state = .loaded(try await env.inbox.inbox()) } catch {
            if state.value == nil { state = .failed(AppError.from(error)) }
        }
    }
}

private struct InboxRow: View {
    let item: InboxItem

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            ZStack(alignment: .bottomTrailing) {
                if let actor = item.actor {
                    AvatarView(name: actor.displayName, url: actor.avatarURL, size: 44)
                } else {
                    Image(systemName: item.symbol)
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Theme.Palette.surfaceMuted, in: Circle())
                }
                if item.actor != nil {
                    Image(systemName: item.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Palette.canvas)
                        .frame(width: 20, height: 20)
                        .background(Theme.Palette.ink, in: Circle())
                        .overlay(Circle().stroke(Theme.Palette.canvas, lineWidth: 2))
                        .offset(x: 3, y: 3)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                message.font(.subheadline).foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption).foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
            if !item.isRead {
                Circle().fill(Theme.Palette.accent).frame(width: 8, height: 8).padding(.top, 6)
                    .accessibilityLabel(Text("stories.new"))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// Localized strings use Markdown so names and titles render in bold.
    private var message: Text {
        let name = item.actor?.displayName ?? ""
        let title = item.activityTitle ?? ""
        switch item.kind {
        case .joinRequest: return Text("inbox.join_request \(name) \(title)")
        case .memberJoined: return Text("inbox.member_joined \(name) \(title)")
        case .requestApproved: return Text("inbox.approved \(title)")
        case .requestDeclined: return Text("inbox.declined \(title)")
        case .activityCancelled: return Text("inbox.cancelled \(title)")
        case .welcome: return Text("inbox.welcome")
        }
    }
}
