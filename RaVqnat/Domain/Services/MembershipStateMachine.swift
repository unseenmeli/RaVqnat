import Foundation

/// The membership state model. The same table of transitions is enforced in Postgres by
/// `public.membership_transition_allowed` and the `activity_members_enforce_transition` trigger.
enum MembershipStateMachine {
    enum Actor: Sendable { case host, member, system }

    struct Transition: Hashable, Sendable {
        let from: MembershipState?
        let to: MembershipState
    }

    /// `from == nil` means "no membership row yet".
    static func isAllowed(from: MembershipState?, to: MembershipState, actor: Actor) -> Bool {
        switch (from, to, actor) {
        case (nil, .pending, .member), (nil, .approved, .system): // .system = open join policy auto-approval
            return true
        case (.cancelled?, .pending, .member), (.cancelled?, .approved, .system):
            return true
        case (.pending?, .approved, .host), (.pending?, .approved, .system),
             (.pending?, .rejected, .host),
             (.pending?, .cancelled, .member), (.pending?, .cancelled, .system):
            return true
        case (.approved?, .cancelled, .member), (.approved?, .cancelled, .system),
             (.approved?, .removed, .host), (.approved?, .removed, .system),
             (.approved?, .attended, .host), (.approved?, .noShow, .host):
            return true
        case (.attended?, .noShow, .host), (.noShow?, .attended, .host):
            return true // hosts may correct attendance
        default:
            return false
        }
    }

    /// Validates a transition and also the capacity invariant.
    static func validate(from: MembershipState?, to: MembershipState, actor: Actor,
                         approvedCount: Int, capacity: Int) throws(AppError) {
        guard isAllowed(from: from, to: to, actor: actor) else {
            throw .rule(.invalidTransition)
        }
        let wasOccupying = from?.occupiesSpot ?? false
        if to.occupiesSpot && !wasOccupying && approvedCount >= capacity {
            throw .rule(.activityFull)
        }
    }
}
