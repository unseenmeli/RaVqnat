import Foundation

/// Activity times are stored in UTC and displayed in the activity's IANA time zone
/// (Asia/Tbilisi for the launch market), regardless of the device's time zone.
enum ActivityTime {
    static let defaultTimeZoneID = "Asia/Tbilisi"
    static var defaultTimeZone: TimeZone { TimeZone(identifier: defaultTimeZoneID) ?? .current }

    static func timeZone(_ id: String?) -> TimeZone {
        id.flatMap(TimeZone.init(identifier:)) ?? defaultTimeZone
    }

    static func calendar(_ timeZoneID: String? = nil) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone(timeZoneID)
        calendar.locale = .autoupdatingCurrent
        return calendar
    }

    /// "Today, 17:00", "Tomorrow, 10:30" or "Sat 14 Jun, 17:00".
    static func smartString(_ date: Date, timeZoneID: String? = nil, now: Date = .now) -> String {
        let tz = timeZone(timeZoneID)
        let cal = calendar(timeZoneID)
        let time = date.formatted(Date.FormatStyle(timeZone: tz).hour().minute())
        if cal.isDate(date, inSameDayAs: now) {
            return String(localized: "time.today_at \(time)")
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "time.tomorrow_at \(time)")
        }
        let day = date.formatted(Date.FormatStyle(timeZone: tz).weekday(.abbreviated).day().month(.abbreviated))
        return "\(day), \(time)"
    }

    static func fullString(_ date: Date, timeZoneID: String? = nil) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone(timeZoneID)).weekday(.wide).day().month(.wide).hour().minute())
    }

    static func timeString(_ date: Date, timeZoneID: String? = nil) -> String {
        date.formatted(Date.FormatStyle(timeZone: timeZone(timeZoneID)).hour().minute())
    }

    static func relativeString(_ date: Date, now: Date = .now) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
