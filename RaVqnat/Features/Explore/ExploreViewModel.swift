import Foundation
import Observation

enum SearchArea: Hashable, Sendable {
    case anywhere
    case nearMe
    case neighborhood(String)
}

/// Everything the user can filter by. Edited as a whole in the filter sheet.
struct ExploreFilters: Equatable, Sendable {
    var area: SearchArea = .anywhere
    var categories: Set<ActivityCategory> = []
    var date: DateFilter = .any
    var customDays: Set<String> = []
    var onlyWithSpots = false
    var beginnerFriendly = false

    var isEmpty: Bool { self == ExploreFilters() }

    /// Short labels describing the active filters, for the home-screen summary chip.
    var summary: [String] {
        var parts: [String] = []
        switch date {
        case .any: break
        case .custom where !customDays.isEmpty: parts.append(String(localized: "filter.days_selected \(customDays.count)"))
        case .custom: break
        default: parts.append(date.title)
        }
        if categories.count == 1, let only = categories.first { parts.append(only.title) }
        else if categories.count > 1 { parts.append(String(localized: "filter.categories_selected \(categories.count)")) }
        switch area {
        case .anywhere: break
        case .nearMe: parts.append(String(localized: "explore.near_you"))
        case .neighborhood(let id): if let hood = Neighborhood.find(id) { parts.append(hood.name) }
        }
        if onlyWithSpots { parts.append(String(localized: "filter.has_spots")) }
        if beginnerFriendly { parts.append(String(localized: "filter.beginner")) }
        return parts
    }
}

@MainActor
@Observable
final class ExploreViewModel {
    private(set) var filters = ExploreFilters()
    private(set) var query = ActivityQuery()
    private(set) var state: LoadState<[Activity]> = .idle
    private(set) var nextCursor: Int?
    private(set) var isLoadingMore = false
    private(set) var joiningIDs: Set<UUID> = []
    var toast: String?
    var error: AppError?
    /// Set when "Near me" was chosen but location is unavailable.
    var locationUnavailable = false

    private let activities: any ActivityRepository
    private let memberships: any MembershipRepository
    /// Distances are measured from the user's home neighbourhood unless "Near me" is active.
    private var homeCenter: Coordinate = .tbilisiCenter
    let pageSize = 10
    private var loadGeneration = 0

    init(activities: any ActivityRepository, memberships: any MembershipRepository) {
        self.activities = activities
        self.memberships = memberships
    }

    func configure(homeNeighborhoodID: String?) {
        homeCenter = Neighborhood.find(homeNeighborhoodID)?.center ?? .tbilisiCenter
        rebuildQuery(deviceLocation: nil)
    }

    /// Applies new filters. "Near me" asks for a single when-in-use location fix.
    func apply(_ newFilters: ExploreFilters, location: LocationProvider) async {
        var resolved = newFilters
        var deviceLocation: Coordinate?
        if newFilters.area == .nearMe {
            deviceLocation = await location.currentLocation()
            if deviceLocation == nil {
                resolved.area = .anywhere
                locationUnavailable = true
            }
        }
        filters = resolved
        rebuildQuery(deviceLocation: deviceLocation)
    }

    func clearFilters() {
        filters = ExploreFilters()
        rebuildQuery(deviceLocation: nil)
    }

    private func rebuildQuery(deviceLocation: Coordinate?) {
        var query = ActivityQuery()
        query.origin = deviceLocation ?? homeCenter
        query.radiusMeters = deviceLocation != nil ? 5_000 : 15_000
        query.categories = filters.categories
        query.date = filters.date
        query.customDays = filters.date == .custom ? filters.customDays : []
        if case .neighborhood(let id) = filters.area { query.neighborhoodID = id }
        query.onlyWithSpots = filters.onlyWithSpots
        query.beginnerFriendly = filters.beginnerFriendly
        self.query = query
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        if state.value == nil { state = .loading }
        do {
            let page = try await activities.nearbyActivities(query, cursor: nil, pageSize: pageSize)
            guard generation == loadGeneration else { return }
            state = .loaded(page.items)
            nextCursor = page.nextCursor
        } catch {
            guard generation == loadGeneration else { return }
            let appError = AppError.from(error)
            if state.value == nil { state = .failed(appError) } else { self.error = appError }
        }
    }

    func loadMoreIfNeeded(current: Activity) async {
        guard let items = state.value, let cursor = nextCursor, !isLoadingMore,
              items.suffix(3).contains(where: { $0.id == current.id }) else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let generation = loadGeneration
        do {
            let page = try await activities.nearbyActivities(query, cursor: cursor, pageSize: pageSize)
            guard generation == loadGeneration else { return }
            let existing = Set(items.map(\.id))
            state = .loaded(items + page.items.filter { !existing.contains($0.id) })
            nextCursor = page.nextCursor
        } catch {
            self.error = AppError.from(error)
        }
    }

    /// Not optimistic: the server decides (capacity, blocks, policy), so we show progress and
    /// then the confirmed state.
    func requestJoin(_ activity: Activity) async -> Bool {
        guard !joiningIDs.contains(activity.id) else { return false }
        joiningIDs.insert(activity.id)
        defer { joiningIDs.remove(activity.id) }
        do {
            let newState = try await memberships.requestToJoin(activityID: activity.id, note: nil)
            replace(activity.id) { $0.myMembership = newState; if newState.occupiesSpot { $0.approvedCount += 1 } }
            toast = newState == .approved ? String(localized: "join.toast.joined") : String(localized: "join.toast.requested")
            Haptics.success()
            return true
        } catch {
            self.error = AppError.from(error)
            Haptics.error()
            if case .rule(.activityFull) = AppError.from(error) { await load() }
            return false
        }
    }

    func replace(_ id: UUID, _ mutate: (inout Activity) -> Void) {
        guard var items = state.value, let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
        state = .loaded(items)
    }
}
