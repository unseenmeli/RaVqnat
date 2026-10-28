import UIKit
import UserNotifications
import Observation

/// Remote notification registration. Permission is requested in context (first join request or
/// first hosted activity), never at launch. Denial is respected and surfaced in Settings.
@MainActor
@Observable
final class PushNotificationService {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let repository: any NotificationRepository
    private let environment: String
    private let isEnabled: Bool
    private var currentToken: String?

    init(repository: any NotificationRepository, environment: String, isEnabled: Bool) {
        self.repository = repository
        self.environment = environment
        self.isEnabled = isEnabled
    }

    func refreshStatus() async {
        guard isEnabled else { return }
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Asks for permission if it has never been asked. Returns whether notifications are allowed.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        guard isEnabled else { return false }
        await refreshStatus()
        if authorizationStatus == .notDetermined {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            await refreshStatus()
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            return granted
        }
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func registerIfAuthorized() async {
        guard isEnabled else { return }
        await refreshStatus()
        if authorizationStatus == .authorized || authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        currentToken = token
        Task {
            do { try await repository.registerDeviceToken(token, environment: environment) }
            catch { Log.push.error("Device token registration failed") }
        }
    }

    func unregister() async {
        guard let token = currentToken else { return }
        try? await repository.unregisterDeviceToken(token)
        currentToken = nil
    }
}
