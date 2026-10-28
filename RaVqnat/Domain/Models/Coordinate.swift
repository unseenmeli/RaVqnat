import CoreLocation

struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    var clLocation: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func distance(to other: Coordinate) -> Double {
        clLocation.distance(from: other.clLocation)
    }

    /// Rough bounding box of the Tbilisi service area (mirrors `public.service_area_contains` in SQL).
    static let tbilisiCenter = Coordinate(latitude: 41.7151, longitude: 44.8271)
    static func isInTbilisiServiceArea(_ c: Coordinate) -> Bool {
        (41.60...41.85).contains(c.latitude) && (44.65...45.05).contains(c.longitude)
    }
}
