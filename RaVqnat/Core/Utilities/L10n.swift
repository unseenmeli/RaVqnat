import Foundation

enum L10n {
    /// Looks up a key built at runtime (e.g. `"interest.\(id)"`). `String(localized:)` would treat
    /// the interpolation as a format argument and look up `"interest.%@"` instead. Every dynamic
    /// key family is listed in the string catalog and checked by `scripts/check_localizations.py`.
    static func dynamic(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}
