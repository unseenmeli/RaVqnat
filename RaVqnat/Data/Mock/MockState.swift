import Foundation

/// Persisted state of the mock backend. Shapes mirror the database tables.
struct MockState: Codable, Sendable {
    struct User: Codable, Sendable {
        var id: UUID
        var displayName: String
        var bio: String
        var avatarURL: URL?
        var interestIDs: [String]
        var preferredLanguage: AppLanguage
        var homeNeighborhoodID: String?
        var onboardingCompleted: Bool
        var ageAssurance: AgeAssurance
        var verification: VerificationState
        var restrictions: AccountRestrictions
        var memberSince: Date
    }

    struct ActivityRow: Codable, Sendable {
        var id: UUID
        var hostID: UUID
        var title: String
        var description: String
        var category: ActivityCategory
        var startsAt: Date
        var endsAt: Date?
        var timeZoneID: String
        var capacity: Int
        var neighborhoodID: String
        var approxCoordinate: Coordinate
        var status: ActivityStatus
        var joinPolicy: JoinPolicy
        var skillLevel: SkillLevel
        var equipment: String?
        var instructions: String?
        var coverImageURL: URL?
        var createdAt: Date
        var updatedAt: Date
        var clientRequestID: UUID?
        // Private details
        var venueName: String
        var address: String
        var exactCoordinate: Coordinate
        var meetingNotes: String?
    }

    struct MemberRow: Codable, Sendable {
        var activityID: UUID
        var userID: UUID
        var state: MembershipState
        var note: String?
        var requestedAt: Date
        var updatedAt: Date
    }

    struct MessageRow: Codable, Sendable {
        var id: UUID
        var activityID: UUID
        var senderID: UUID?
        var body: String
        var createdAt: Date
        var clientMessageID: UUID?
    }

    struct BlockRow: Codable, Sendable {
        var blockerID: UUID
        var blockedID: UUID
        var createdAt: Date
    }

    struct ReportRow: Codable, Sendable {
        var id: UUID
        var reporterID: UUID?
        var reportedUserID: UUID?
        var activityID: UUID?
        var messageID: UUID?
        var storyID: UUID?
        var category: ReportCategory
        var description: String
        var status: ModerationStatus
        var createdAt: Date
        var clientRequestID: UUID
    }

    struct StoryRow: Codable, Sendable {
        var id: UUID
        var activityID: UUID
        var authorID: UUID?
        var kind: StoryKind
        var text: String?
        var mediaURL: URL?
        var background: StoryBackground
        var createdAt: Date
        var expiresAt: Date
    }

    struct FeedbackRow: Codable, Sendable {
        var activityID: UUID
        var reviewerID: UUID
        var rating: Int
        var feltSafe: Bool?
        var comment: String
        var createdAt: Date
    }

    var schemaVersion = 2
    var currentUserID: UUID?
    var users: [UUID: User] = [:]
    var activities: [UUID: ActivityRow] = [:]
    var members: [MemberRow] = []
    var messages: [MessageRow] = []
    var blocks: [BlockRow] = []
    var reports: [ReportRow] = []
    var feedback: [FeedbackRow] = []
    var stories: [StoryRow] = []
    var storyViews: [String: Date] = [:]
    var readState: [String: Date] = [:]
    var preferences: [UUID: NotificationPreferences] = [:]
    var deviceTokens: [String: UUID] = [:]
}

extension MockState.ActivityRow {
    /// Stories can be posted until 24 h after an activity ends ("moments from today").
    var effectiveEndForStories: Date {
        (endsAt ?? startsAt.addingTimeInterval(2 * 3600)).addingTimeInterval(Story.lifetime)
    }
}
