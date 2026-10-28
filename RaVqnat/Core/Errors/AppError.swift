import Foundation

/// Business rules the server (and the mock backend) can reject a request with.
/// Raw values are the stable codes raised by the Postgres functions (`raise exception 'activity_full'`).
enum RuleViolation: String, Sendable, Equatable, CaseIterable {
    case activityFull = "activity_full"
    case activityNotOpen = "activity_not_open"
    case notEligibleToHost = "not_eligible_to_host"
    case verificationRequired = "verification_required"
    case hostingRestricted = "hosting_restricted"
    case accountSuspended = "account_suspended"
    case invalidTransition = "invalid_transition"
    case unavailable = "unavailable"
    case alreadyRequested = "already_requested"
    case requestClosed = "request_closed"
    case notParticipant = "not_participant"
    case notHost = "not_host"
    case capacityBelowApproved = "capacity_below_approved"
    case invalidInput = "invalid_input"
    case invalidSchedule = "invalid_schedule"
    case publicVenueRequired = "public_venue_required"
    case outsideServiceArea = "outside_service_area"
    case onboardingIncomplete = "onboarding_incomplete"
    case ageRequirement = "age_requirement"
    case cannotReportSelf = "cannot_report_self"
    case cannotBlockSelf = "cannot_block_self"
    case feedbackNotAllowed = "feedback_not_allowed"
    case activityStarted = "activity_started"

    var message: String {
        switch self {
        case .activityFull: String(localized: "error.rule.activity_full")
        case .activityNotOpen: String(localized: "error.rule.activity_not_open")
        case .notEligibleToHost, .verificationRequired: String(localized: "error.rule.verification_required")
        case .hostingRestricted: String(localized: "error.rule.hosting_restricted")
        case .accountSuspended: String(localized: "error.rule.account_suspended")
        case .invalidTransition, .requestClosed: String(localized: "error.rule.request_closed")
        case .unavailable: String(localized: "error.rule.unavailable")
        case .alreadyRequested: String(localized: "error.rule.already_requested")
        case .notParticipant: String(localized: "error.rule.not_participant")
        case .notHost: String(localized: "error.rule.not_host")
        case .capacityBelowApproved: String(localized: "error.rule.capacity_below_approved")
        case .invalidInput: String(localized: "error.rule.invalid_input")
        case .invalidSchedule: String(localized: "error.rule.invalid_schedule")
        case .publicVenueRequired: String(localized: "error.rule.public_venue_required")
        case .outsideServiceArea: String(localized: "error.rule.outside_service_area")
        case .onboardingIncomplete: String(localized: "error.rule.onboarding_incomplete")
        case .ageRequirement: String(localized: "error.rule.age_requirement")
        case .cannotReportSelf: String(localized: "error.rule.cannot_report_self")
        case .cannotBlockSelf: String(localized: "error.rule.cannot_block_self")
        case .feedbackNotAllowed: String(localized: "error.rule.feedback_not_allowed")
        case .activityStarted: String(localized: "error.rule.activity_started")
        }
    }
}

/// The single error type surfaced to view models. Messages are localized and never contain
/// server internals.
enum AppError: Error, Sendable, Equatable {
    case offline
    case network
    case unauthorized
    case notFound
    case rateLimited
    case rule(RuleViolation)
    case signInCancelled
    case signInFailed
    case unknown

    var message: String {
        switch self {
        case .offline: String(localized: "error.offline")
        case .network: String(localized: "error.network")
        case .unauthorized: String(localized: "error.unauthorized")
        case .notFound: String(localized: "error.not_found")
        case .rateLimited: String(localized: "error.rate_limited")
        case .rule(let rule): rule.message
        case .signInCancelled: String(localized: "error.sign_in_cancelled")
        case .signInFailed: String(localized: "error.sign_in_failed")
        case .unknown: String(localized: "error.unknown")
        }
    }

    var isRetryable: Bool {
        switch self {
        case .offline, .network, .unknown: true
        default: false
        }
    }

    /// Maps any thrown error to an `AppError` without leaking details.
    static func from(_ error: any Error) -> AppError {
        if let app = error as? AppError { return app }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: return .offline
            case .userAuthenticationRequired: return .unauthorized
            default: return .network
            }
        }
        if error is CancellationError { return .unknown }
        return .unknown
    }

    /// Recognises a server-side rule code inside an error message (e.g. a PostgREST error body).
    static func fromServerMessage(_ message: String?) -> AppError? {
        guard let message else { return nil }
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("rate_limited") { return .rateLimited }
        if normalized.contains("not_found") { return .notFound }
        if normalized.contains("not_authenticated") { return .unauthorized }
        for rule in RuleViolation.allCases where normalized.contains(rule.rawValue) {
            return .rule(rule)
        }
        return nil
    }
}
