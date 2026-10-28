import Foundation

/// Validates activity drafts. Mirrors the checks in `public.create_activity` / `public.update_activity`.
struct ActivityValidator: Sendable {
    enum Issue: String, Hashable, Sendable, CaseIterable {
        case titleTooShort, titleTooLong, descriptionTooShort, descriptionTooLong
        case missingCategory, startTooSoon, startTooFar, endBeforeStart, durationTooLong
        case capacityOutOfRange, missingNeighborhood, missingVenue, missingLocation
        case outsideServiceArea, venueNotConfirmedPublic, fieldTooLong

        var message: String { L10n.dynamic("validation.activity.\(rawValue)") }
    }

    static let titleRange = 4...80
    static let descriptionRange = 10...2000
    static let shortTextLimit = 300

    var policy: TrustPolicy

    func issues(for draft: ActivityDraft, now: Date = .now, approvedCount: Int = 0, isEditing: Bool = false) -> [Issue] {
        var issues: [Issue] = []
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.count < Self.titleRange.lowerBound { issues.append(.titleTooShort) }
        if title.count > Self.titleRange.upperBound { issues.append(.titleTooLong) }
        if description.count < Self.descriptionRange.lowerBound { issues.append(.descriptionTooShort) }
        if description.count > Self.descriptionRange.upperBound { issues.append(.descriptionTooLong) }
        if draft.category == nil { issues.append(.missingCategory) }

        if !isEditing || draft.startsAt < now {
            if draft.startsAt < now.addingTimeInterval(TimeInterval(policy.minLeadTimeMinutes * 60)) {
                issues.append(.startTooSoon)
            }
        }
        if draft.startsAt > now.addingTimeInterval(TimeInterval(policy.maxDaysAhead * 86_400)) {
            issues.append(.startTooFar)
        }
        if draft.hasEndTime {
            if draft.endsAt <= draft.startsAt { issues.append(.endBeforeStart) }
            else if draft.endsAt.timeIntervalSince(draft.startsAt) > TimeInterval(policy.maxDurationHours * 3600) {
                issues.append(.durationTooLong)
            }
        }

        let minCapacity = max(policy.minCapacity, approvedCount)
        if draft.capacity < minCapacity || draft.capacity > policy.maxCapacity { issues.append(.capacityOutOfRange) }
        if draft.neighborhoodID == nil { issues.append(.missingNeighborhood) }
        if draft.venueName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 { issues.append(.missingVenue) }
        if let coordinate = draft.meetingCoordinate {
            if !Coordinate.isInTbilisiServiceArea(coordinate) { issues.append(.outsideServiceArea) }
        } else {
            issues.append(.missingLocation)
        }
        if policy.requirePublicVenue && !draft.venueIsPublic { issues.append(.venueNotConfirmedPublic) }

        let shortFields = [draft.venueName, draft.address, draft.equipment, draft.meetingNotes]
        if shortFields.contains(where: { $0.count > Self.shortTextLimit }) || draft.instructions.count > 1000 {
            issues.append(.fieldTooLong)
        }
        return issues
    }
}
