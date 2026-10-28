import OSLog

/// Privacy-aware logging. Interpolated values default to `.private` in OSLog, so user content,
/// identifiers and tokens are redacted in release logs unless explicitly marked public.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "ge.ravqnat.app"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let push = Logger(subsystem: subsystem, category: "push")
    static let chat = Logger(subsystem: subsystem, category: "chat")
}
