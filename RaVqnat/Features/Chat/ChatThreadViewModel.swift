import Foundation
import Observation

@MainActor
@Observable
final class ChatThreadViewModel {
    struct Item: Identifiable, Hashable {
        enum Delivery: Hashable { case sent, sending, failed }
        let message: ChatMessage
        var delivery: Delivery
        var id: UUID { message.clientMessageID ?? message.id }
    }

    let activityID: UUID
    private(set) var items: [Item] = []
    private(set) var activity: Activity?
    private(set) var loadState: LoadState<Void> = .idle
    private(set) var isLoadingOlder = false
    private(set) var hasMoreHistory = true
    var draft = ""
    var error: AppError?
    private(set) var hiddenSenderIDs: Set<UUID> = []

    static let pageSize = 30
    static let maxLength = 2000

    private let chat: any ChatRepository
    private let activities: any ActivityRepository
    private let safety: any SafetyRepository

    init(activityID: UUID, chat: any ChatRepository, activities: any ActivityRepository, safety: any SafetyRepository) {
        self.activityID = activityID
        self.chat = chat
        self.activities = activities
        self.safety = safety
    }

    var canSend: Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= Self.maxLength && activity?.status != .cancelled
    }

    func load() async {
        loadState = .loading
        do {
            async let activity = activities.activity(id: activityID)
            async let messages = chat.messages(activityID: activityID, before: nil, limit: Self.pageSize)
            self.activity = try await activity
            let page = try await messages
            items = page.map { Item(message: $0, delivery: .sent) }
            hasMoreHistory = page.count == Self.pageSize
            loadState = .loaded(())
            try? await chat.markRead(activityID: activityID)
        } catch {
            loadState = .failed(AppError.from(error))
        }
    }

    func loadOlder() async {
        guard hasMoreHistory, !isLoadingOlder, let oldest = items.first?.message.createdAt else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await chat.messages(activityID: activityID, before: oldest, limit: Self.pageSize)
            let known = Set(items.map(\.message.id))
            items.insert(contentsOf: page.filter { !known.contains($0.id) }.map { Item(message: $0, delivery: .sent) }, at: 0)
            hasMoreHistory = page.count == Self.pageSize
        } catch {
            self.error = AppError.from(error)
        }
    }

    /// Consumes the realtime stream until the calling task is cancelled.
    func listen() async {
        for await message in chat.liveMessages(activityID: activityID) {
            receive(message)
        }
    }

    func receive(_ message: ChatMessage) {
        guard message.activityID == activityID, !hiddenSenderIDs.contains(message.sender.id) else { return }
        if let clientID = message.clientMessageID, let index = items.firstIndex(where: { $0.message.clientMessageID == clientID }) {
            items[index] = Item(message: message, delivery: .sent)
        } else if !items.contains(where: { $0.message.id == message.id }) {
            items.append(Item(message: message, delivery: .sent))
        }
        Task { try? await chat.markRead(activityID: activityID) }
    }

    /// Optimistic send is safe here: the client message ID makes the server call idempotent and
    /// the bubble is clearly marked as sending/failed until confirmed.
    func send(as sender: UserSummary) async {
        guard canSend else { return }
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        let clientID = UUID()
        let pending = ChatMessage(id: clientID, activityID: activityID, sender: sender, body: body, createdAt: .now, clientMessageID: clientID)
        items.append(Item(message: pending, delivery: .sending))
        await deliver(pending)
    }

    func retry(_ item: Item) async {
        guard item.delivery == .failed, let index = items.firstIndex(of: item) else { return }
        items[index].delivery = .sending
        await deliver(item.message)
    }

    private func deliver(_ pending: ChatMessage) async {
        do {
            let confirmed = try await chat.send(activityID: activityID, body: pending.body, clientMessageID: pending.clientMessageID ?? pending.id)
            receive(confirmed)
        } catch {
            if let index = items.firstIndex(where: { $0.message.clientMessageID == pending.clientMessageID }) {
                items[index].delivery = .failed
            }
            self.error = AppError.from(error)
            Haptics.error()
        }
    }

    func block(_ user: UserSummary) async {
        do {
            try await safety.block(userID: user.id)
            hiddenSenderIDs.insert(user.id)
            items.removeAll { $0.message.sender.id == user.id }
            Haptics.success()
        } catch {
            self.error = AppError.from(error)
        }
    }
}
