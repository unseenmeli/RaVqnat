import Foundation
import Network
import Observation

/// Publishes connectivity so screens can show an offline banner instead of failing silently.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "ge.ravqnat.network-monitor"))
    }

    deinit { monitor.cancel() }
}
