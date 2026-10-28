import SwiftUI

struct ChatListView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppRouter.self) private var router
    @State private var state: LoadState<[ChatThread]> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                List(0..<5, id: \.self) { _ in ThreadRowSkeleton() }.listStyle(.plain)
            case .failed(let error):
                ErrorStateView(error: error) { Task { await load() } }
            case .loaded(let threads) where threads.isEmpty:
                EmptyStateView(symbol: "bubble.left.and.bubble.right", title: String(localized: "chats.empty.title"),
                               message: String(localized: "chats.empty.message"),
                               actionTitle: String(localized: "chats.empty.action")) { router.selectedTab = .explore }
            case .loaded(let threads):
                List(threads) { thread in
                    NavigationLink(value: Route.chat(thread.activityID)) { ThreadRow(thread: thread) }
                }
                .listStyle(.plain)
            }
        }
        .screenBackground()
        .navigationTitle(Text("tab.chats"))
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: router.chatsPath) { _, path in if path.isEmpty { Task { await load() } } }
    }

    private func load() async {
        if state.value == nil { state = .loading }
        do { state = .loaded(try await env.chat.threads()) } catch {
            if state.value == nil { state = .failed(AppError.from(error)) }
        }
    }
}

private struct ThreadRow: View {
    let thread: ChatThread

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: thread.category.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(thread.category.tint)
                .frame(width: 52, height: 52)
                .background(thread.category.softTint, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(thread.title).font(.body.weight(.semibold)).foregroundStyle(Theme.Palette.ink).lineLimit(1)
                    Spacer()
                    if let date = thread.lastMessageAt {
                        Text(date.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))
                            .font(.caption).foregroundStyle(Theme.Palette.inkTertiary)
                    }
                }
                HStack {
                    Text(thread.status == .cancelled ? String(localized: "activity.status.cancelled") : (thread.lastMessagePreview ?? String(localized: "chats.no_messages")))
                        .font(.subheadline)
                        .foregroundStyle(thread.unreadCount > 0 ? Theme.Palette.ink : Theme.Palette.inkSecondary)
                        .lineLimit(1)
                    Spacer()
                    if thread.unreadCount > 0 {
                        Text("\(min(thread.unreadCount, 99))")
                            .font(.caption.monospaced().bold()).foregroundStyle(.white)
                            .padding(.horizontal, 6).frame(minWidth: 22, minHeight: 22)
                            .background(Theme.Palette.accent, in: Capsule())
                            .accessibilityLabel(Text("chats.unread \(thread.unreadCount)"))
                    }
                }
                Text(ActivityTime.smartString(thread.startsAt, timeZoneID: thread.timeZoneID))
                    .font(.caption).foregroundStyle(Theme.Palette.inkTertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ThreadRowSkeleton: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            RoundedRectangle(cornerRadius: 16).frame(width: 52, height: 52)
            VStack(alignment: .leading) {
                Text(verbatim: "Activity title placeholder")
                Text(verbatim: "Last message preview text")
            }
        }
        .skeleton()
    }
}
