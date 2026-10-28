import Foundation
import UserNotifications

/// Local notifications for activity reminders and optional safety check-ins.
///
/// Check-ins are entirely on-device: no location is collected and nobody is contacted
/// automatically. "Get help" only opens the in-app emergency guidance.
@MainActor
final class ReminderScheduler {
    nonisolated static let checkInCategory = "SAFETY_CHECKIN"
    nonisolated static let checkInOkayAction = "CHECKIN_OK"
    nonisolated static let checkInHelpAction = "CHECKIN_HELP"

    private let isEnabled: Bool
    private var center: UNUserNotificationCenter { .current() }

    init(isEnabled: Bool) { self.isEnabled = isEnabled }

    func registerCategories() {
        guard isEnabled else { return }
        let ok = UNNotificationAction(identifier: Self.checkInOkayAction, title: String(localized: "checkin.action.ok"), options: [])
        let help = UNNotificationAction(identifier: Self.checkInHelpAction, title: String(localized: "checkin.action.help"), options: [.foreground])
        let category = UNNotificationCategory(identifier: Self.checkInCategory, actions: [ok, help], intentIdentifiers: [],
                                              options: [.hiddenPreviewsShowTitle])
        center.setNotificationCategories([category])
    }

    func scheduleReminder(for activity: Activity, leadTime: TimeInterval = 3600) async {
        guard isEnabled else { return }
        let fireDate = activity.startsAt.addingTimeInterval(-leadTime)
        guard fireDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "reminder.title")
        content.body = String(localized: "reminder.body \(activity.title) \(ActivityTime.timeString(activity.startsAt, timeZoneID: activity.timeZoneID))")
        content.sound = .default
        content.userInfo = ["deeplink": DeepLink.activity(activity.id).url.absoluteString]
        await add(id: "reminder.\(activity.id)", content: content, at: fireDate)
    }

    func scheduleCheckIn(for activity: Activity, after: TimeInterval = 30 * 60) async {
        guard isEnabled else { return }
        let fireDate = activity.effectiveEnd.addingTimeInterval(after)
        guard fireDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "checkin.title")
        content.body = String(localized: "checkin.body")
        content.categoryIdentifier = Self.checkInCategory
        content.userInfo = ["deeplink": DeepLink.safety.url.absoluteString]
        content.interruptionLevel = .timeSensitive
        await add(id: "checkin.\(activity.id)", content: content, at: fireDate)
    }

    func cancel(activityID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder.\(activityID)", "checkin.\(activityID)"])
    }

    func cancelCheckIn(activityID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["checkin.\(activityID)"])
    }

    func cancelAll() async {
        guard isEnabled else { return }
        center.removeAllPendingNotificationRequests()
    }

    private func add(id: String, content: UNNotificationContent, at date: Date) async {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        do { try await center.add(request) } catch { Log.push.error("Scheduling local notification failed") }
    }
}
