import Foundation

enum HostingEligibility: Equatable, Sendable {
    case eligible
    case onboardingIncomplete
    case needsVerification
    case hostingRestricted(until: Date?)
    case suspended(until: Date?)

    var isEligible: Bool { self == .eligible }
}

/// Client-side mirror of `public.can_host()` used for UX only. The server re-checks every rule.
struct TrustPolicyEvaluator: Sendable {
    var policy: TrustPolicy

    func hostingEligibility(for profile: MyProfile, now: Date = .now) -> HostingEligibility {
        if profile.restrictions.isSuspended(at: now) { return .suspended(until: profile.restrictions.suspendedUntil) }
        if !profile.onboardingCompleted { return .onboardingIncomplete }
        if profile.restrictions.isHostingRestricted(at: now) {
            return .hostingRestricted(until: profile.restrictions.hostingRestrictedUntil)
        }
        if policy.hostingRequiresVerification && !profile.verification.isCurrentlyVerified(at: now) {
            return .needsVerification
        }
        return .eligible
    }

    func canJoin(_ profile: MyProfile, now: Date = .now) -> Bool {
        profile.onboardingCompleted && !profile.restrictions.isSuspended(at: now)
    }
}
