import Foundation

enum MembershipState: String, Codable, Sendable, CaseIterable {
    case pending, approved, rejected, cancelled, removed, attended
    case noShow = "no_show"

    var title: String {
        switch self {
        case .pending: String(localized: "membership.pending")
        case .approved: String(localized: "membership.approved")
        case .rejected: String(localized: "membership.rejected")
        case .cancelled: String(localized: "membership.cancelled")
        case .removed: String(localized: "membership.removed")
        case .attended: String(localized: "membership.attended")
        case .noShow: String(localized: "membership.no_show")
        }
    }

    /// States that occupy a spot.
    var occupiesSpot: Bool { self == .approved || self == .attended }
}

struct Member: Identifiable, Hashable, Sendable {
    var id: UUID { user.id }
    var user: UserSummary
    var state: MembershipState
    var note: String?
    var requestedAt: Date
}
