import Foundation

enum OnboardingValidator {
    static let nameRange = 2...40
    static let maxInterests = 10
    static let bioLimit = 300

    enum Issue: String, Hashable, Sendable {
        case nameTooShort, nameTooLong, nameInvalid, notAdult, noInterests, tooManyInterests
        var message: String { L10n.dynamic("validation.onboarding.\(rawValue)") }
    }

    static func normalizedName(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func nameIssue(_ raw: String) -> Issue? {
        let name = normalizedName(raw)
        if name.count < nameRange.lowerBound { return .nameTooShort }
        if name.count > nameRange.upperBound { return .nameTooLong }
        // Letters (any script, incl. Georgian), spaces, hyphens, apostrophes and dots only.
        let allowed = CharacterSet.letters.union(.init(charactersIn: " -'’."))
        if name.unicodeScalars.contains(where: { !allowed.contains($0) }) { return .nameInvalid }
        return nil
    }

    static func issues(for submission: OnboardingSubmission) -> [Issue] {
        var issues: [Issue] = []
        if let nameIssue = nameIssue(submission.displayName) { issues.append(nameIssue) }
        if !submission.confirmsAdult { issues.append(.notAdult) }
        if submission.interestIDs.isEmpty { issues.append(.noInterests) }
        if submission.interestIDs.count > maxInterests { issues.append(.tooManyInterests) }
        return issues
    }
}
