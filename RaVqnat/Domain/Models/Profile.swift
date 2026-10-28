import Foundation

enum AppLanguage: String, Codable, CaseIterable, Sendable, Identifiable {
    case ka, en
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ka: "ქართული"
        case .en: "English"
        }
    }
}

enum VerificationStatus: String, Codable, Sendable, CaseIterable {
    case unverified, pending, verified, failed, expired, revoked

    var title: String {
        switch self {
        case .unverified: String(localized: "verification.status.unverified")
        case .pending: String(localized: "verification.status.pending")
        case .verified: String(localized: "verification.status.verified")
        case .failed: String(localized: "verification.status.failed")
        case .expired: String(localized: "verification.status.expired")
        case .revoked: String(localized: "verification.status.revoked")
        }
    }
}

enum AgeAssurance: String, Codable, Sendable {
    case none, selfDeclared = "self_declared", verified
}

/// Minimal information about another user — the only shape other people's data takes in the app.
/// It intentionally has no email, phone, birth date or location fields.
struct UserSummary: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var displayName: String
    var avatarURL: URL?
    var isVerified: Bool
}

struct PublicProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var bio: String
    var avatarURL: URL?
    var interestIDs: [String]
    var isVerified: Bool
    var memberSince: Date
    var hostedActivityCount: Int

    var summary: UserSummary { .init(id: id, displayName: displayName, avatarURL: avatarURL, isVerified: isVerified) }
}

struct AccountRestrictions: Hashable, Codable, Sendable {
    var suspendedUntil: Date?
    var hostingRestrictedUntil: Date?

    static let none = AccountRestrictions()

    func isSuspended(at now: Date = .now) -> Bool { suspendedUntil.map { $0 > now } ?? false }
    func isHostingRestricted(at now: Date = .now) -> Bool { hostingRestrictedUntil.map { $0 > now } ?? false }
}

struct VerificationState: Hashable, Codable, Sendable {
    var status: VerificationStatus
    var verifiedAt: Date?
    var expiresAt: Date?
    var provider: String?

    static let unverified = VerificationState(status: .unverified)

    func isCurrentlyVerified(at now: Date = .now) -> Bool {
        guard status == .verified else { return false }
        if let expiresAt, expiresAt <= now { return false }
        return true
    }
}

/// The signed-in user's own profile, including private settings.
struct MyProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var bio: String
    var avatarURL: URL?
    var interestIDs: [String]
    var preferredLanguage: AppLanguage
    var onboardingCompleted: Bool
    var ageAssurance: AgeAssurance
    var verification: VerificationState
    var restrictions: AccountRestrictions
    var memberSince: Date

    var isVerified: Bool { verification.isCurrentlyVerified() }
    var summary: UserSummary { .init(id: id, displayName: displayName, avatarURL: avatarURL, isVerified: isVerified) }
}

struct ProfileUpdate: Sendable, Equatable {
    var displayName: String
    var bio: String
    var interestIDs: [String]
    var preferredLanguage: AppLanguage
}

struct OnboardingSubmission: Sendable, Equatable {
    var displayName: String
    var confirmsAdult: Bool
    var interestIDs: [String]
    var preferredLanguage: AppLanguage
}
