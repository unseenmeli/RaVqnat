import CoreLocation
import Observation

/// When-in-use location only, requested at the moment the user asks for nearby results.
/// The location is used as a query parameter and never stored or shared.
@MainActor
@Observable
final class LocationProvider: NSObject {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var lastKnown: Coordinate?
    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<Coordinate?, Never>] = []

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isDenied: Bool { authorization == .denied || authorization == .restricted }
    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }

    /// Requests permission if needed, then a single coarse fix. Returns nil if unavailable.
    func currentLocation() async -> Coordinate? {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isDenied {
            return nil
        }
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
            if isAuthorized { manager.requestLocation() }
        }
    }

    private func finish(_ coordinate: Coordinate?) {
        if let coordinate { lastKnown = coordinate }
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume(returning: coordinate) }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if self.isAuthorized, !self.continuations.isEmpty { self.manager.requestLocation() }
            if self.isDenied { self.finish(nil) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map { Coordinate($0.coordinate) }
        Task { @MainActor in self.finish(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
