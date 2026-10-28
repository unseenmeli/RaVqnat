import MapKit
import SwiftUI

@MainActor
@Observable
final class MapDiscoveryViewModel {
    private(set) var state: LoadState<[Activity]> = .idle
    var cellDegrees = 0.004
    var selectedID: UUID?
    var categories: Set<ActivityCategory> = []

    private let activities: any ActivityRepository
    init(activities: any ActivityRepository) { self.activities = activities }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            var query = ActivityQuery()
            query.radiusMeters = 25_000
            query.categories = categories
            state = .loaded(try await activities.nearbyActivities(query, cursor: nil, pageSize: 200).items)
        } catch {
            state = .failed(AppError.from(error))
        }
    }

    var clusters: [MapClustering.Cluster] {
        let items = (state.value ?? []).map { (id: $0.id, coordinate: $0.approxCoordinate) }
        return MapClustering.cluster(items, cellDegrees: cellDegrees)
    }

    func activity(_ id: UUID?) -> Activity? { state.value?.first { $0.id == id } }
}

struct MapDiscoveryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @State private var model: MapDiscoveryViewModel?
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: Coordinate.tbilisiCenter.clCoordinate, latitudinalMeters: 9000, longitudinalMeters: 9000))
    @State private var showList = false
    @State private var showNeighborhoods = false
    @State private var locationDenied = false

    var body: some View {
        Group {
            if let model { content(model) } else { Color.clear }
        }
        .navigationTitle(Text("tab.map"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if model == nil { model = MapDiscoveryViewModel(activities: env.activities) } }
    }

    @ViewBuilder private func content(_ model: MapDiscoveryViewModel) -> some View {
        ZStack(alignment: .bottom) {
            if showList {
                listView(model)
            } else {
                map(model)
                if let activity = model.activity(model.selectedID) {
                    NavigationLink(value: Route.activity(activity.id)) {
                        ActivityRow(activity: activity).rvCard(padding: Theme.Spacing.m)
                    }
                    .buttonStyle(.plain)
                    .padding(Theme.Spacing.l)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("map.preview")
                }
            }
        }
        .animation(.spring(duration: 0.3), value: model.selectedID)
        .task { await model.load() }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showNeighborhoods = true } label: { Image(systemName: "mappin.and.ellipse") }
                    .accessibilityLabel(Text("explore.choose_neighborhood"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { withAnimation { showList.toggle() } } label: {
                    Label(showList ? String(localized: "map.show_map") : String(localized: "map.show_list"),
                          systemImage: showList ? "map" : "list.bullet")
                }
                .accessibilityIdentifier("map.toggle")
            }
        }
        .sheet(isPresented: $showNeighborhoods) {
            NeighborhoodPickerSheet(selected: nil) { id in
                let center = Neighborhood.find(id)?.center ?? .tbilisiCenter
                withAnimation {
                    position = .region(MKCoordinateRegion(center: center.clCoordinate, latitudinalMeters: id == nil ? 9000 : 2500,
                                                          longitudinalMeters: id == nil ? 9000 : 2500))
                }
            }
        }
        .alert(Text("map.location_denied.title"), isPresented: $locationDenied) {
            Button("map.location_denied.choose") { showNeighborhoods = true }
            Button("action.open_settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            Button("action.cancel", role: .cancel) {}
        } message: { Text("map.location_denied.message") }
    }

    private func map(_ model: MapDiscoveryViewModel) -> some View {
        Map(position: $position) {
            ForEach(model.clusters) { cluster in
                Annotation(coordinate: cluster.coordinate.clCoordinate, anchor: .center) {
                    if cluster.isSingle, let activity = model.activity(cluster.activityIDs.first) {
                        ActivityPin(category: activity.category, isSelected: model.selectedID == activity.id)
                            .onTapGesture { model.selectedID = activity.id; Haptics.selection() }
                            .accessibilityLabel(Text(activity.title))
                            .accessibilityAddTraits(.isButton)
                    } else {
                        ClusterPin(count: cluster.activityIDs.count)
                            .onTapGesture { zoom(into: cluster) }
                            .accessibilityLabel(Text("map.cluster \(cluster.activityIDs.count)"))
                            .accessibilityAddTraits(.isButton)
                    }
                } label: {
                    EmptyView()
                }
                .annotationTitles(.hidden)
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            model.cellDegrees = max(0.0005, context.region.span.latitudeDelta / 9)
        }
        .onTapGesture { model.selectedID = nil }
        .overlay(alignment: .topTrailing) {
            Button {
                Task {
                    if let coordinate = await env.location.currentLocation() {
                        withAnimation {
                            position = .region(MKCoordinateRegion(center: coordinate.clCoordinate, latitudinalMeters: 3000, longitudinalMeters: 3000))
                        }
                    } else if env.location.isDenied {
                        locationDenied = true
                    }
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .padding(Theme.Spacing.l)
            .accessibilityLabel(Text("explore.near_me"))
        }
        .overlay {
            if case .failed(let error) = model.state {
                ErrorStateView(error: error) { Task { await model.load() } }.rvCard().padding()
            }
        }
    }

    private func listView(_ model: MapDiscoveryViewModel) -> some View {
        List {
            ForEach(model.state.value ?? []) { activity in
                NavigationLink(value: Route.activity(activity.id)) { ActivityRow(activity: activity) }
            }
        }
        .listStyle(.plain)
        .overlay {
            if model.state.isLoading { ProgressView() }
            if let items = model.state.value, items.isEmpty {
                EmptyStateView(symbol: "map", title: String(localized: "explore.empty.title"), message: String(localized: "explore.empty.message"))
            }
        }
    }

    private func zoom(into cluster: MapClustering.Cluster) {
        let span = max(0.002, model?.cellDegrees ?? 0.01) * 3
        withAnimation {
            position = .region(MKCoordinateRegion(center: cluster.coordinate.clCoordinate,
                                                  span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)))
        }
    }
}

private struct ActivityPin: View {
    let category: ActivityCategory
    let isSelected: Bool

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: isSelected ? 18 : 14, weight: .bold))
            .foregroundStyle(Theme.Palette.canvas)
            .frame(width: isSelected ? 46 : 34, height: isSelected ? 46 : 34)
            .background(Theme.Palette.ink, in: Circle())
            .overlay(Circle().strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.canvas, lineWidth: isSelected ? 3 : 2))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            .animation(.spring(duration: 0.25), value: isSelected)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
    }
}

private struct ClusterPin: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.Palette.ink)
            .frame(width: 42, height: 42)
            .background(Theme.Palette.surface, in: Circle())
            .overlay(Circle().strokeBorder(Theme.Palette.ink, lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
    }
}
