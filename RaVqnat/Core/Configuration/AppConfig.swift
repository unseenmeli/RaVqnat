import Foundation

/// Runtime configuration resolved from Info.plist (populated from xcconfig) and launch arguments.
/// Only public values live here: the Supabase anon key is designed to ship in clients.
struct AppConfig: Sendable, Equatable {
    enum Backend: Sendable, Equatable {
        case supabase(url: URL, anonKey: String)
        case mock
    }

    let backend: Backend
    let apnsEnvironment: String
    let isUITesting: Bool
    /// When true the mock backend starts from a fresh seed instead of the persisted state.
    let resetMockState: Bool

    var isMockMode: Bool { backend == .mock }

    static func load(bundle: Bundle = .main, arguments: [String] = ProcessInfo.processInfo.arguments) -> AppConfig {
        let isUITesting = arguments.contains(LaunchArgument.uiTesting)
        let forceMock = isUITesting || arguments.contains(LaunchArgument.mock)
        let apns = (bundle.object(forInfoDictionaryKey: "RVAPNSEnvironment") as? String) ?? "development"

        let backend: Backend
        if !forceMock,
           let rawURL = (bundle.object(forInfoDictionaryKey: "RVSupabaseURL") as? String)?.trimmingCharacters(in: .whitespaces),
           let key = (bundle.object(forInfoDictionaryKey: "RVSupabaseAnonKey") as? String)?.trimmingCharacters(in: .whitespaces),
           !key.isEmpty,
           let url = URL(string: rawURL),
           url.scheme == "https" || url.host == "127.0.0.1" || url.host == "localhost" {
            backend = .supabase(url: url, anonKey: key)
        } else {
            backend = .mock
        }

        return AppConfig(
            backend: backend,
            apnsEnvironment: apns,
            isUITesting: isUITesting,
            resetMockState: isUITesting || arguments.contains(LaunchArgument.resetMock)
        )
    }
}

enum LaunchArgument {
    static let uiTesting = "-uitest"
    static let mock = "-mock"
    static let resetMock = "-reset-mock"
    /// UI tests: start signed in as the seeded demo user with onboarding completed.
    static let signedIn = "-uitest-signed-in"
}
