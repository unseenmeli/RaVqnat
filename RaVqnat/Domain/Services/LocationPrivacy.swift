import Foundation

/// Location privacy helpers. Public activity coordinates are snapped to a coarse grid so a map
/// pin never reveals the exact venue; the server applies the same rule
/// (`public.approximate_location`) and is the source of truth.
enum LocationPrivacy {
    /// Grid size in degrees (~330 m latitude, ~250 m longitude at Tbilisi's latitude).
    static let gridDegrees = 0.003

    static func approximate(_ coordinate: Coordinate) -> Coordinate {
        func snap(_ value: Double) -> Double {
            ((value / gridDegrees).rounded() * gridDegrees * 1_000_000).rounded() / 1_000_000
        }
        return Coordinate(latitude: snap(coordinate.latitude), longitude: snap(coordinate.longitude))
    }

    /// Radius (m) of the circle drawn around an approximate location so it reads as an area.
    static let displayRadiusMeters = 350.0

    /// Distances are rounded so they cannot be used to triangulate a venue.
    static func roundedDistance(_ meters: Double) -> Double {
        if meters < 1000 { return max(100, (meters / 100).rounded() * 100) }
        return (meters / 500).rounded() * 500
    }

    static func distanceString(_ meters: Double) -> String {
        let rounded = roundedDistance(meters)
        let measurement = Measurement(value: rounded, unit: UnitLength.meters)
        return measurement.formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
