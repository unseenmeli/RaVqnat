import Foundation
import Observation

@MainActor
@Observable
final class ActivityFormViewModel {
    enum Mode: Equatable {
        case create
        case edit(Activity, ActivityPrivateDetails?)
    }

    let mode: Mode
    var draft: ActivityDraft
    private(set) var isSubmitting = false
    /// Validation messages are shown only after the first submit attempt.
    private(set) var showIssues = false
    var error: AppError?

    private let activities: any ActivityRepository
    private let validator: ActivityValidator

    init(mode: Mode, activities: any ActivityRepository, policy: TrustPolicy, defaultNeighborhood: String?) {
        self.mode = mode
        self.activities = activities
        self.validator = ActivityValidator(policy: policy)
        switch mode {
        case .create:
            var draft = ActivityDraft()
            draft.neighborhoodID = defaultNeighborhood
            self.draft = draft
        case .edit(let activity, let details):
            self.draft = ActivityDraft(editing: activity, details: details)
        }
    }

    var policy: TrustPolicy { validator.policy }
    var isEditing: Bool { mode != .create }
    var approvedCount: Int { if case .edit(let a, _) = mode { a.approvedCount } else { 0 } }

    var issues: [ActivityValidator.Issue] {
        validator.issues(for: draft, approvedCount: approvedCount, isEditing: isEditing)
    }

    func issue(_ candidates: ActivityValidator.Issue...) -> String? {
        guard showIssues else { return nil }
        return issues.first { candidates.contains($0) }?.message
    }

    var capacityRange: ClosedRange<Int> { max(policy.minCapacity, approvedCount)...policy.maxCapacity }

    func selectNeighborhood(_ id: String) {
        draft.neighborhoodID = id
        if draft.meetingCoordinate == nil { draft.meetingCoordinate = Neighborhood.find(id)?.center }
    }

    /// Submits once; repeated taps while in flight are ignored and retries reuse the draft's
    /// idempotency key, so a flaky network can never create two activities.
    func submit() async -> Activity? {
        showIssues = true
        guard issues.isEmpty, !isSubmitting else {
            Haptics.warning()
            return nil
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let result: Activity
            switch mode {
            case .create: result = try await activities.createActivity(draft)
            case .edit(let activity, _): result = try await activities.updateActivity(id: activity.id, draft: draft)
            }
            Haptics.success()
            return result
        } catch {
            self.error = AppError.from(error)
            Haptics.error()
            return nil
        }
    }
}
