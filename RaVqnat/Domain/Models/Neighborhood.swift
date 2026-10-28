import Foundation

/// Tbilisi neighbourhoods. Mirrors `public.neighborhoods`; names are localized in the string catalog.
struct Neighborhood: Identifiable, Hashable, Sendable {
    let id: String
    let center: Coordinate

    var name: String { L10n.dynamic("neighborhood.\(id)") }

    static let all: [Neighborhood] = [
        .init(id: "vake", center: .init(latitude: 41.7087, longitude: 44.7650)),
        .init(id: "saburtalo", center: .init(latitude: 41.7285, longitude: 44.7535)),
        .init(id: "vera", center: .init(latitude: 41.7076, longitude: 44.7798)),
        .init(id: "chugureti", center: .init(latitude: 41.7218, longitude: 44.8000)),
        .init(id: "sololaki", center: .init(latitude: 41.6893, longitude: 44.8003)),
        .init(id: "mtatsminda", center: .init(latitude: 41.6950, longitude: 44.7900)),
        .init(id: "old_tbilisi", center: .init(latitude: 41.6910, longitude: 44.8080)),
        .init(id: "avlabari", center: .init(latitude: 41.6935, longitude: 44.8150)),
        .init(id: "didube", center: .init(latitude: 41.7410, longitude: 44.7820)),
        .init(id: "isani", center: .init(latitude: 41.6890, longitude: 44.8420)),
        .init(id: "nadzaladevi", center: .init(latitude: 41.7470, longitude: 44.7980)),
        .init(id: "gldani", center: .init(latitude: 41.7880, longitude: 44.8160)),
    ]

    static func find(_ id: String?) -> Neighborhood? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func nearest(to coordinate: Coordinate) -> Neighborhood {
        all.min { $0.center.distance(to: coordinate) < $1.center.distance(to: coordinate) } ?? all[0]
    }
}
