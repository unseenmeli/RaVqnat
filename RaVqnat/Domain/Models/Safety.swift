import Foundation

enum ReportCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case harassment
    case sexualMisconduct = "sexual_misconduct"
    case threats
    case hateSpeech = "hate_speech"
    case inappropriateMessage = "inappropriate_message"
    case fakeProfile = "fake_profile"
    case unsafeActivity = "unsafe_activity"
    case other

    var id: String { rawValue }
    var title: String { L10n.dynamic("report.category.\(rawValue)") }
}

enum ModerationStatus: String, Codable, Sendable {
    case open, inReview = "in_review", actioned, dismissed
    var title: String { L10n.dynamic("report.status.\(rawValue)") }
}

struct ReportDraft: Sendable, Equatable {
    var reportedUserID: UUID
    var activityID: UUID?
    var messageID: UUID?
    var category: ReportCategory?
    var description = ""
    var clientRequestID = UUID()

    static let maxDescriptionLength = 2000
}

struct ReportRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    let category: ReportCategory
    let status: ModerationStatus
    let createdAt: Date
    let reportedUserName: String?
}

struct BlockedUser: Identifiable, Hashable, Sendable {
    var id: UUID { user.id }
    let user: UserSummary
    let blockedAt: Date
}

struct FeedbackDraft: Sendable, Equatable {
    var activityID: UUID
    var rating: Int = 0
    var feltSafe: Bool?
    var comment = ""
}

struct NotificationPreferences: Codable, Hashable, Sendable {
    var joinRequests = true
    var requestUpdates = true
    var reminders = true
    var chatMessages = true
    var activityUpdates = true
    /// Off by default: lock-screen notifications never contain message text unless opted in.
    var showMessagePreviews = false
}

struct VerificationStart: Sendable, Equatable {
    /// Hosted verification page from the provider, if the provider uses one.
    var url: URL?
    /// True when the server is configured with the development mock provider.
    var isMockProvider: Bool
}

/// Server-provided policy that governs hosting and safety rules. Mirrors `public.trust_policies`.
struct TrustPolicy: Codable, Hashable, Sendable {
    var hostingRequiresVerification = true
    var minimumAge = 18
    var minCapacity = 1
    var maxCapacity = 20
    var requirePublicVenue = true
    var minLeadTimeMinutes = 30
    var maxDaysAhead = 60
    var maxDurationHours = 12

    static let launch = TrustPolicy()
}
