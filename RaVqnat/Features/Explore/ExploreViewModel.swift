import Foundation
import Observation

@MainActor
@Observable
final class ExploreViewModel {
    var query = ActivityQuery()
    private(set) var state: LoadState<[Activity]> = .idle
    private(set) var nextCursor: Int?
    private(set) var isLoadingMore = false
    private(set) var joiningIDs: Set<UUID> = []
    /// Label for the current search origin ("Near you" or a neighbourhood).
    private(set) var originNeighborhoodID: String?
    private(set) var usesDeviceLocation = false
    var toast: String?
    var error: AppError?

    private let activities: any ActivityRepository
    private let memberships: any MembershipRepository
    let pageSize = 10
    private var loadGeneration = 0

    init(activities: any ActivityRepository, memberships: any MembershipRepository) {
        self.activities = activities
        self.memberships = memberships
    }

    func setNeighborhood(_ id: String?) {
        originNeighborhoodID = id
        usesDeviceLocation = false
        query.origin = Neighborhood.find(id)?.center ?? .tbilisiCenter
    }

    func setDeviceLocation(_ coordinate: Coordinate) {
        usesDeviceLocation = true
        originNeighborhoodID = Neighborhood.nearest(to: coordinate).id
        query.origin = coordinate
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

    func toggleCategory(_ category: ActivityCategory) {
        if query.categories.contains(category) { query.categories.remove(category) } else { query.categories.insert(category) }
    }
}
