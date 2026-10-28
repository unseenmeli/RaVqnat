import SwiftUI
import Observation

enum AppTab: String, Hashable, CaseIterable {
    case explore, map, host, chats, profile
}

/// Navigation destinations shared by every tab's stack.
enum Route: Hashable {
    case activity(UUID)
    case chat(UUID)
    case profile(UUID)
    case manage(UUID)
    case safetyCenter
    case inbox
}

/// Deep links: `ravqnat://activity/<uuid>`, `ravqnat://chat/<uuid>`, `ravqnat://safety`.
/// Push payloads carry the same URL in `deeplink`.
enum DeepLink: Equatable {
    case activity(UUID)
    case chat(UUID)
    case safety

    init?(url: URL) {
        guard url.scheme == "ravqnat" else { return nil }
        let id = url.pathComponents.dropFirst().first.flatMap(UUID.init(uuidString:))
        switch url.host {
        case "activity": guard let id else { return nil }; self = .activity(id)
        case "chat": guard let id else { return nil }; self = .chat(id)
        case "safety": self = .safety
        default: return nil
        }
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let string = userInfo["deeplink"] as? String, let url = URL(string: string) else { return nil }
        self.init(url: url)
    }

    var url: URL {
        switch self {
        case .activity(let id): URL(string: "ravqnat://activity/\(id.uuidString.lowercased())")!
        case .chat(let id): URL(string: "ravqnat://chat/\(id.uuidString.lowercased())")!
        case .safety: URL(string: "ravqnat://safety")!
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .explore
    var explorePath: [Route] = []
    var mapPath: [Route] = []
    var hostPath: [Route] = []
    var chatsPath: [Route] = []
    var profilePath: [Route] = []
    /// A deep link received before the user finished signing in is held until `ready`.
    private(set) var pendingDeepLink: DeepLink?

    func handle(_ link: DeepLink, isReady: Bool) {
        guard isReady else {
            pendingDeepLink = link
            return
        }
        pendingDeepLink = nil
        switch link {
        case .activity(let id):
            selectedTab = .explore
            explorePath = [.activity(id)]
        case .chat(let id):
            selectedTab = .chats
            chatsPath = [.chat(id)]
        case .safety:
            selectedTab = .profile
            profilePath = [.safetyCenter]
        }
    }

    func consumePendingDeepLink() {
        if let link = pendingDeepLink { handle(link, isReady: true) }
    }

    func path(for tab: AppTab) -> Binding<[Route]> {
        Binding(
            get: {
                switch tab {
                case .explore: self.explorePath
                case .map: self.mapPath
                case .host: self.hostPath
                case .chats: self.chatsPath
                case .profile: self.profilePath
                }
            },
            set: { newValue in
                switch tab {
                case .explore: self.explorePath = newValue
                case .map: self.mapPath = newValue
                case .host: self.hostPath = newValue
                case .chats: self.chatsPath = newValue
                case .profile: self.profilePath = newValue
                }
            })
    }
}
