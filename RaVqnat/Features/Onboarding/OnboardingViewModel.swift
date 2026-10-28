import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable, Codable {
        case name, age, photo, interests, language, neighborhood
    }

    struct Draft: Codable, Equatable {
        var step: Step = .name
        var displayName = ""
        var confirmsAdult = false
        var interestIDs: [String] = []
        var language: AppLanguage = Locale.current.language.languageCode?.identifier == "ka" ? .ka : .en
        var neighborhoodID: String?
    }

    var draft: Draft { didSet { store.save(draft) } }
    var photoData: Data?
    private(set) var isSubmitting = false
    var error: AppError?

    private let profiles: any ProfileRepository
    private let store: OnboardingDraftStore

    init(profiles: any ProfileRepository, store: OnboardingDraftStore) {
        self.profiles = profiles
        self.store = store
        self.draft = store.load() ?? Draft()
    }

    var step: Step { draft.step }
    var progress: Double { Double(step.rawValue + 1) / Double(Step.allCases.count) }
    var isLastStep: Bool { step == Step.allCases.last }

    var nameIssue: OnboardingValidator.Issue? {
        draft.displayName.isEmpty ? nil : OnboardingValidator.nameIssue(draft.displayName)
    }

    var canContinue: Bool {
        switch step {
        case .name: !draft.displayName.isEmpty && OnboardingValidator.nameIssue(draft.displayName) == nil
        case .age: draft.confirmsAdult
        case .photo, .language: true
        case .interests: !draft.interestIDs.isEmpty && draft.interestIDs.count <= OnboardingValidator.maxInterests
        case .neighborhood: draft.neighborhoodID != nil
        }
    }

    func toggleInterest(_ id: String) {
        if let index = draft.interestIDs.firstIndex(of: id) {
            draft.interestIDs.remove(at: index)
        } else if draft.interestIDs.count < OnboardingValidator.maxInterests {
            draft.interestIDs.append(id)
        }
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        draft.step = previous
    }

    /// Advances, or submits on the last step. Returns the completed profile when done.
    func next() async -> MyProfile? {
        guard canContinue else { return nil }
        if let following = Step(rawValue: step.rawValue + 1) {
            draft.step = following
            return nil
        }
        return await submit()
    }

    private func submit() async -> MyProfile? {
        guard !isSubmitting, let neighborhood = draft.neighborhoodID else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        let submission = OnboardingSubmission(displayName: draft.displayName, confirmsAdult: draft.confirmsAdult,
                                              interestIDs: draft.interestIDs, preferredLanguage: draft.language,
                                              homeNeighborhoodID: neighborhood)
        guard OnboardingValidator.issues(for: submission).isEmpty else {
            error = .rule(.invalidInput)
            return nil
        }
        do {
            var profile = try await profiles.completeOnboarding(submission)
            if let photoData {
                // A failed photo upload must not block onboarding; it can be added later.
                if let updated = try? await profiles.uploadAvatar(jpegData: photoData) { profile = updated }
            }
            store.clear()
            return profile
        } catch {
            self.error = AppError.from(error)
            return nil
        }
    }
}

/// Persists onboarding progress (no photo, nothing sensitive) in a file protected by iOS data
/// protection, so an interrupted onboarding resumes where the user left off.
struct OnboardingDraftStore {
    let url: URL?

    init(userID: UUID?, directory: URL? = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) {
        url = userID.flatMap { id in directory?.appendingPathComponent("onboarding-\(id.uuidString).json") }
    }

    func load() -> OnboardingViewModel.Draft? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OnboardingViewModel.Draft.self, from: data)
    }

    func save(_ draft: OnboardingViewModel.Draft) {
        guard let url, let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
