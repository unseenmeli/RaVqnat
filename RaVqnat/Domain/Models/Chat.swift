import Foundation

struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let activityID: UUID
    let sender: UserSummary
    let body: String
    let createdAt: Date
    /// Client-generated idempotency key used to reconcile optimistic sends with server echoes.
    let clientMessageID: UUID?
}

struct ChatThread: Identifiable, Hashable, Sendable {
    var id: UUID { activityID }
    let activityID: UUID
    var title: String
    var category: ActivityCategory
    var startsAt: Date
    var timeZoneID: String
    var isHost: Bool
    var lastMessagePreview: String?
    var lastMessageAt: Date?
    var unreadCount: Int
    var status: ActivityStatus
}
