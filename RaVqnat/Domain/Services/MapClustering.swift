import Foundation

/// Simple, deterministic grid clustering for map annotations (SwiftUI `Map` has no built-in clustering).
enum MapClustering {
    struct Cluster: Identifiable, Hashable, Sendable {
        let id: String
        let coordinate: Coordinate
        let activityIDs: [UUID]
        var isSingle: Bool { activityIDs.count == 1 }
    }

    /// - Parameter cellDegrees: grid cell size; callers derive it from the visible span (span / 8).
    static func cluster(_ items: [(id: UUID, coordinate: Coordinate)], cellDegrees: Double) -> [Cluster] {
        guard cellDegrees > 0 else {
            return items.map { Cluster(id: $0.id.uuidString, coordinate: $0.coordinate, activityIDs: [$0.id]) }
        }
        var buckets: [String: [(id: UUID, coordinate: Coordinate)]] = [:]
        for item in items {
            let key = "\(Int((item.coordinate.latitude / cellDegrees).rounded(.down)))_\(Int((item.coordinate.longitude / cellDegrees).rounded(.down)))"
            buckets[key, default: []].append(item)
        }
        return buckets.map { key, members in
            let lat = members.map(\.coordinate.latitude).reduce(0, +) / Double(members.count)
            let lon = members.map(\.coordinate.longitude).reduce(0, +) / Double(members.count)
            let ids = members.map(\.id).sorted { $0.uuidString < $1.uuidString }
            return Cluster(id: members.count == 1 ? ids[0].uuidString : "cluster_\(key)",
                           coordinate: Coordinate(latitude: lat, longitude: lon),
                           activityIDs: ids)
        }
        .sorted { $0.id < $1.id }
    }
}
