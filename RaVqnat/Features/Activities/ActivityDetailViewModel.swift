import Foundation
import Observation

@MainActor
@Observable
final class ActivityDetailViewModel {
    let activityID: UUID
    private(set) var state: LoadState<Activity> = .idle
    private(set) var details: ActivityPrivateDetails?
    private(set) var participants: [Member] = []
    private(set) var hasSubmittedFeedback = true
    private(set) var isWorking = false
    var error: AppError?
    var toast: String?

    private let activities: any ActivityRepository
    private let memberships: any MembershipRepository
    private let safety: any SafetyRepository

    init(activityID: UUID, activities: any ActivityRepository, memberships: any MembershipRepository, safety: any SafetyRepository) {
        self.activityID = activityID
        self.activities = activities
        self.memberships = memberships
        self.safety = safety
    }

    var activity: Activity? { state.value }

    func load(viewerID: UUID?) async {
        if state.value == nil { state = .loading }
        do {
            let activity = try await activities.activity(id: activityID)
            state = .loaded(activity)
            if activity.isParticipant(viewerID) {
                async let details = activities.privateDetails(activityID: activityID)
                async let members = memberships.members(activityID: activityID)
                self.details = try await details
                self.participants = ((try? await members) ?? []).filter { $0.state.occupiesSpot }
            } else {
                details = nil
                participants = []
            }
            let participated = !activity.isHost(viewerID) && (activity.myMembership?.occupiesSpot ?? false)
            hasSubmittedFeedback = participated && activity.hasStarted() ? ((try? await safety.hasSubmittedFeedback(activityID: activityID)) ?? true) : true
        } catch {
            if state.value == nil { state = .failed(AppError.from(error)) } else { self.error = AppError.from(error) }
        }
    }

    func canLeaveFeedback(viewerID: UUID?) -> Bool {
        guard let activity else { return false }
        return !activity.isHost(viewerID) && (activity.myMembership?.occupiesSpot ?? false)
            && activity.hasStarted() && !hasSubmittedFeedback
    }

    func requestJoin(note: String?, viewerID: UUID?) async -> MembershipState? {
        isWorking = true
        defer { isWorking = false }
        do {
            let newState = try await memberships.requestToJoin(activityID: activityID, note: note)
            toast = newState == .approved ? String(localized: "join.toast.joined") : String(localized: "join.toast.requested")
            Haptics.success()
            await load(viewerID: viewerID)
            return newState
        } catch {
            self.error = AppError.from(error)
            Haptics.error()
            return nil
        }
    }

    func cancelMembership(viewerID: UUID?) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await memberships.cancelMembership(activityID: activityID)
            toast = String(localized: "join.toast.left")
            await load(viewerID: viewerID)
            return true
        } catch {
            self.error = AppError.from(error)
            return false
        }
    }

    func block(userID: UUID) async -> Bool {
        do {
            try await safety.block(userID: userID)
            Haptics.success()
            return true
        } catch {
            self.error = AppError.from(error)
            return false
        }
    }

    func feedbackSubmitted() {
        hasSubmittedFeedback = true
        toast = String(localized: "feedback.toast")
    }

    /// Text shared with a trusted contact through the system share sheet. Includes exact
    /// meeting details only when the viewer is allowed to see them.
    func shareText() -> String {
        guard let activity else { return "" }
        var lines = [
            String(localized: "share.intro"),
            "• \(activity.title)",
            "• \(ActivityTime.fullString(activity.startsAt, timeZoneID: activity.timeZoneID))",
        ]
        if let details {
            lines.append("• \(details.venueName), \(details.address)")
            lines.append("• https://maps.apple.com/?ll=\(details.coordinate.latitude),\(details.coordinate.longitude)")
        } else if let hood = activity.neighborhood {
            lines.append("• \(hood.name)")
        }
        lines.append("• \(String(localized: "share.host")) \(activity.host.displayName)")
        return lines.joined(separator: "\n")
    }
}
