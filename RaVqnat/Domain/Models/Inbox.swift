import Foundation

/// In-app notification. Text is composed on device from `kind` so it follows the UI language.
enum InboxKind: String, Codable, Sendable {
    case joinRequest = "join_request"
    case memberJoined = "member_joined"
    case requestApproved = "request_approved"
    case requestDeclined = "request_declined"
    case activityCancelled = "activity_cancelled"
    case welcome
}

struct InboxItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: InboxKind
    let activityID: UUID?
    let activityTitle: String?
    let actor: UserSummary?
    let createdAt: Date
    let isRead: Bool

    /// Where tapping the notification goes.
    var route: Route? {
        switch kind {
        case .joinRequest, .memberJoined: activityID.map(Route.manage)
        case .requestApproved, .requestDeclined, .activityCancelled: activityID.map(Route.activity)
        case .welcome: .safetyCenter
        }
    }

    var symbol: String {
        switch kind {
        case .joinRequest: "person.badge.plus"
        case .memberJoined: "person.2.fill"
        case .requestApproved: "checkmark.circle.fill"
        case .requestDeclined: "xmark.circle"
        case .activityCancelled: "calendar.badge.exclamationmark"
        case .welcome: "hand.wave.fill"
        }
    }
}
