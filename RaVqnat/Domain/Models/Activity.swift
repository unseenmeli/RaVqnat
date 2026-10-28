import Foundation

enum ActivityStatus: String, Codable, Sendable {
    case published, cancelled, completed, removed
}

enum JoinPolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    case approvalRequired = "approval_required"
    case open
    var id: String { rawValue }
    var title: String {
        switch self {
        case .approvalRequired: String(localized: "join_policy.approval")
        case .open: String(localized: "join_policy.open")
        }
    }
}

enum SkillLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case allLevels = "all_levels", beginner, intermediate, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .allLevels: String(localized: "skill.all_levels")
        case .beginner: String(localized: "skill.beginner")
        case .intermediate: String(localized: "skill.intermediate")
        case .advanced: String(localized: "skill.advanced")
        }
    }
}

struct Activity: Identifiable, Hashable, Sendable {
    let id: UUID
    var host: UserSummary
    var title: String
    var description: String
    var category: ActivityCategory
    var startsAt: Date
    var endsAt: Date?
    var timeZoneID: String
    /// Number of participants the host accepts (the host is not counted).
    var capacity: Int
    var approvedCount: Int
    var neighborhoodID: String
    /// Public, deliberately imprecise location (snapped to a ~300 m grid server-side).
    var approxCoordinate: Coordinate
    var status: ActivityStatus
    var joinPolicy: JoinPolicy
    var skillLevel: SkillLevel
    var equipment: String?
    var instructions: String?
    var coverImageURL: URL?
    var createdAt: Date
    /// The viewer's membership, if any.
    var myMembership: MembershipState?
    /// Distance from the viewer's search origin, computed server-side from the approximate location.
    var distanceMeters: Double?

    var spotsLeft: Int { max(0, capacity - approvedCount) }
    var isFull: Bool { spotsLeft == 0 }
    var isBeginnerFriendly: Bool { skillLevel == .beginner || skillLevel == .allLevels }
    var neighborhood: Neighborhood? { Neighborhood.find(neighborhoodID) }
    var effectiveEnd: Date { endsAt ?? startsAt.addingTimeInterval(2 * 3600) }

    func hasStarted(at now: Date = .now) -> Bool { startsAt <= now }
    func hasEnded(at now: Date = .now) -> Bool { effectiveEnd <= now }
    func isHost(_ userID: UUID?) -> Bool { host.id == userID }

    /// Whether the viewer may see the chat and exact meeting details.
    func isParticipant(_ userID: UUID?) -> Bool {
        isHost(userID) || myMembership == .approved || myMembership == .attended
    }
}

/// Exact meeting details, only returned to the host and approved participants.
struct ActivityPrivateDetails: Hashable, Sendable {
    var venueName: String
    var address: String
    var coordinate: Coordinate
    var meetingNotes: String?
}

/// Input for creating or editing an activity.
struct ActivityDraft: Sendable, Equatable {
    var title = ""
    var description = ""
    var category: ActivityCategory?
    var startsAt: Date
    var hasEndTime = false
    var endsAt: Date
    var capacity = 6
    var neighborhoodID: String?
    var venueName = ""
    var address = ""
    var meetingCoordinate: Coordinate?
    var meetingNotes = ""
    var venueIsPublic = false
    var skillLevel: SkillLevel = .allLevels
    var equipment = ""
    var instructions = ""
    var joinPolicy: JoinPolicy = .approvalRequired
    var coverImageData: Data?
    /// Idempotency key: retrying a submission with the same draft never creates a duplicate.
    var clientRequestID = UUID()

    init(now: Date = .now) {
        let calendar = ActivityTime.calendar()
        let inTwoHours = now.addingTimeInterval(2 * 3600)
        let rounded = calendar.nextDate(after: inTwoHours, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? inTwoHours
        startsAt = rounded
        endsAt = rounded.addingTimeInterval(2 * 3600)
    }

    init(editing activity: Activity, details: ActivityPrivateDetails?) {
        self.init()
        title = activity.title
        description = activity.description
        category = activity.category
        startsAt = activity.startsAt
        hasEndTime = activity.endsAt != nil
        endsAt = activity.endsAt ?? activity.startsAt.addingTimeInterval(2 * 3600)
        capacity = activity.capacity
        neighborhoodID = activity.neighborhoodID
        venueName = details?.venueName ?? ""
        address = details?.address ?? ""
        meetingCoordinate = details?.coordinate
        meetingNotes = details?.meetingNotes ?? ""
        venueIsPublic = true
        skillLevel = activity.skillLevel
        equipment = activity.equipment ?? ""
        instructions = activity.instructions ?? ""
        joinPolicy = activity.joinPolicy
    }
}

enum DateFilter: String, CaseIterable, Sendable, Identifiable {
    case any, today, tomorrow, weekend, thisWeek, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .any: String(localized: "filter.date.any")
        case .today: String(localized: "filter.date.today")
        case .tomorrow: String(localized: "filter.date.tomorrow")
        case .thisWeek: String(localized: "filter.date.this_week")
        case .weekend: String(localized: "filter.date.weekend")
        case .custom: String(localized: "filter.date.custom")
        }
    }

    var symbol: String {
        switch self {
        case .any: "infinity"
        case .today: "sun.max"
        case .tomorrow: "sunrise"
        case .weekend: "figure.walk"
        case .thisWeek: "calendar"
        case .custom: "calendar.badge.plus"
        }
    }

    /// The UTC interval this filter covers, evaluated in the Tbilisi calendar.
    func interval(now: Date = .now) -> DateInterval? {
        let cal = ActivityTime.calendar()
        let startOfToday = cal.startOfDay(for: now)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: startOfToday)! }
        switch self {
        case .any, .custom: return nil
        case .today: return DateInterval(start: now, end: day(1))
        case .tomorrow: return DateInterval(start: day(1), end: day(2))
        case .thisWeek: return DateInterval(start: now, end: day(7))
        case .weekend:
            let weekday = cal.component(.weekday, from: now) // 1 = Sunday, 7 = Saturday
            let daysToSaturday = (7 - weekday) % 7
            let saturday = day(daysToSaturday)
            let start = max(now, weekday == 1 ? startOfToday : saturday)
            let end = weekday == 1 ? day(1) : cal.date(byAdding: .day, value: 2, to: saturday)!
            return DateInterval(start: start, end: max(start, end))
        }
    }
}

struct ActivityQuery: Sendable, Equatable {
    var origin: Coordinate = .tbilisiCenter
    var radiusMeters: Double = 15_000
    var categories: Set<ActivityCategory> = []
    var date: DateFilter = .any
    /// Exact days (Tbilisi calendar, "yyyy-MM-dd") when `date == .custom`.
    var customDays: Set<String> = []
    var neighborhoodID: String?
    var onlyWithSpots = false
    var beginnerFriendly = false

    /// True if the start date passes the date filter (preset interval or exact days).
    func matchesDate(_ startsAt: Date, now: Date = .now) -> Bool {
        switch date {
        case .any: true
        case .custom: customDays.isEmpty || customDays.contains(ActivityQuery.dayKey(startsAt))
        default: date.interval(now: now)?.contains(startsAt) ?? true
        }
    }

    static func dayKey(_ date: Date) -> String {
        let c = ActivityTime.calendar().dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

struct Page<Item: Sendable>: Sendable {
    var items: [Item]
    var nextCursor: Int?
}
