import Foundation
import Observation

/// Dependency container. One instance per app run; injected through the SwiftUI environment and
/// passed explicitly into view models (which only ever see protocols).
@MainActor
@Observable
final class AppEnvironment {
    let config: AppConfig
    let auth: any AuthRepository
    let profiles: any ProfileRepository
    let activities: any ActivityRepository
    let memberships: any MembershipRepository
    let chat: any ChatRepository
    let safety: any SafetyRepository
    let stories: any StoryRepository
    let inbox: any InboxRepository
    let verification: any VerificationRepository
    let notificationsRepository: any NotificationRepository
    let push: PushNotificationService
    let reminders: ReminderScheduler
    let location: LocationProvider
    let network: NetworkMonitor
    let preferences: LocalPreferences

    init(config: AppConfig, auth: any AuthRepository, profiles: any ProfileRepository,
         activities: any ActivityRepository, memberships: any MembershipRepository, chat: any ChatRepository,
         safety: any SafetyRepository, stories: any StoryRepository, inbox: any InboxRepository,
         verification: any VerificationRepository,
         notifications: any NotificationRepository, preferences: LocalPreferences = LocalPreferences()) {
        self.config = config
        self.auth = auth
        self.profiles = profiles
        self.activities = activities
        self.memberships = memberships
        self.chat = chat
        self.safety = safety
        self.stories = stories
        self.inbox = inbox
        self.verification = verification
        self.notificationsRepository = notifications
        self.preferences = preferences
        self.push = PushNotificationService(repository: notifications, environment: config.apnsEnvironment,
                                            isEnabled: !config.isUITesting)
        self.reminders = ReminderScheduler(isEnabled: !config.isUITesting)
        self.location = LocationProvider()
        self.network = NetworkMonitor()
    }

    static func make(config: AppConfig) -> AppEnvironment {
        switch config.backend {
        case .supabase:
            // The Supabase data layer lands in the next milestone; until then a configured
            // backend still runs on local mock data so the app stays usable.
            Log.app.fault("Supabase repositories not yet available; using mock backend")
            return mock(config: config)
        case .mock:
            return mock(config: config)
        }
    }

    static func mock(config: AppConfig, backend: MockBackend? = nil) -> AppEnvironment {
        let persistence = MockBackend.defaultPersistenceURL()
        if config.resetMockState, let persistence { try? FileManager.default.removeItem(at: persistence) }
        let backend = backend ?? MockBackend(options: .init(
            persistenceURL: config.isUITesting ? nil : persistence,
            simulateOtherUsers: true,
            simulationDelay: config.isUITesting ? .seconds(1) : .seconds(3)))
        let preferences = LocalPreferences(defaults: config.isUITesting ? UserDefaults(suiteName: "uitest")! : .standard)
        if config.resetMockState { preferences.reset() }
        return AppEnvironment(config: config, auth: backend, profiles: backend, activities: backend,
                              memberships: backend, chat: backend, safety: backend, stories: backend, inbox: backend, verification: backend,
                              notifications: backend, preferences: preferences)
    }

    /// Environment for SwiftUI previews.
    static let preview: AppEnvironment = mock(config: AppConfig(backend: .mock, apnsEnvironment: "development",
                                                                isUITesting: true, resetMockState: false))
}

/// Small, non-sensitive per-device preferences.
@MainActor
final class LocalPreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(_ name: String, _ userID: UUID) -> String { "\(name).\(userID.uuidString)" }

    func hasAcknowledgedSafetyGuidelines(_ userID: UUID) -> Bool { defaults.bool(forKey: key("safety.ack", userID)) }
    func acknowledgeSafetyGuidelines(_ userID: UUID) { defaults.set(true, forKey: key("safety.ack", userID)) }

    func checkInEnabled(activityID: UUID) -> Bool { defaults.bool(forKey: "checkin.\(activityID.uuidString)") }
    func setCheckInEnabled(_ enabled: Bool, activityID: UUID) { defaults.set(enabled, forKey: "checkin.\(activityID.uuidString)") }

    func reset() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("safety.") || key.hasPrefix("checkin.") || key.hasPrefix("explore.") || key.hasPrefix("onboarding.") {
            defaults.removeObject(forKey: key)
        }
    }
}
