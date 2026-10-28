import UIKit
import UserNotifications

/// Bridges UIKit callbacks (APNs registration, notification responses) into the SwiftUI app.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor var onDeviceToken: ((Data) -> Void)?
    @MainActor var onDeepLink: ((DeepLink) -> Void)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        onDeviceToken?(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Log.push.error("APNs registration failed")
    }

    /// Foreground presentation: show banners except for chat messages of the chat already open
    /// (the chat screen shows those inline).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let action = response.actionIdentifier
        let link: DeepLink? = action == ReminderScheduler.checkInOkayAction ? nil : DeepLink(userInfo: content.userInfo)
        guard let link else { return }
        await MainActor.run { self.onDeepLink?(link) }
    }
}
