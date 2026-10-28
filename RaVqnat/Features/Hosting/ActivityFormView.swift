import MapKit
import PhotosUI
import SwiftUI

struct ActivityFormView: View {
    let mode: ActivityFormViewModel.Mode
    let onDone: (Activity) -> Void
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @State private var model: ActivityFormViewModel?

    var body: some View {
        Group {
            if let model { ActivityFormContent(model: model, onDone: onDone) } else { Color.clear }
        }
        .onAppear {
            if model == nil {
                model = ActivityFormViewModel(mode: mode, activities: env.activities, policy: session.trustPolicy,
                                              defaultNeighborhood: nil)
            }
        }
    }
}

private struct ActivityFormContent: View {
    @Bindable var model: ActivityFormViewModel
    let onDone: (Activity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var coverItem: PhotosPickerItem?
    @State private var showOptional = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
                        ForEach(ActivityCategory.allCases) { category in
                            CategoryTile(category: category, isSelected: model.draft.category == category) {
                                model.draft.category = category
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    errorText(model.issue(.missingCategory))
                } header: { Text("form.category") }

                Section {
                    TextField(text: $model.draft.title) { Text("form.title.placeholder") }
                        .accessibilityIdentifier("form.title")
                    errorText(model.issue(.titleTooShort, .titleTooLong))
                    TextField(text: $model.draft.description, axis: .vertical) { Text("form.description.placeholder") }
                        .lineLimit(3...8)
                        .accessibilityIdentifier("form.description")
                    errorText(model.issue(.descriptionTooShort, .descriptionTooLong))
                } header: { Text("form.what") }

                Section {
                    DatePicker(selection: $model.draft.startsAt, in: Date.now..., displayedComponents: [.date, .hourAndMinute]) {
                        Text("form.starts")
                    }
                    .environment(\.timeZone, ActivityTime.defaultTimeZone)
                    Toggle("form.has_end", isOn: $model.draft.hasEndTime.animation()).tint(Theme.Palette.brand)
                    if model.draft.hasEndTime {
                        DatePicker(selection: $model.draft.endsAt, in: model.draft.startsAt..., displayedComponents: [.date, .hourAndMinute]) {
                            Text("form.ends")
                        }
                        .environment(\.timeZone, ActivityTime.defaultTimeZone)
                    }
                    errorText(model.issue(.startTooSoon, .startTooFar, .endBeforeStart, .durationTooLong))
                    Stepper(value: $model.draft.capacity, in: model.capacityRange) {
                        HStack {
                            Text("form.capacity")
                            Spacer()
                            Text("\(model.draft.capacity)").monospacedDigit().foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                    .accessibilityValue(Text("\(model.draft.capacity)"))
                    errorText(model.issue(.capacityOutOfRange))
                } header: { Text("form.when") } footer: {
                    Text("form.when.footer")
                }

                Section {
                    Picker(selection: Binding(get: { model.draft.neighborhoodID }, set: { if let id = $0 { model.selectNeighborhood(id) } })) {
                        Text("form.choose").tag(String?.none)
                        ForEach(Neighborhood.all) { Text($0.name).tag(Optional($0.id)) }
                    } label: { Text("form.neighborhood") }
                    errorText(model.issue(.missingNeighborhood))
                    TextField(text: $model.draft.venueName) { Text("form.venue.placeholder") }
                        .accessibilityIdentifier("form.venue")
                    errorText(model.issue(.missingVenue))
                    TextField(text: $model.draft.address) { Text("form.address.placeholder") }
                    MeetingPointPicker(coordinate: $model.draft.meetingCoordinate,
                                       fallback: Neighborhood.find(model.draft.neighborhoodID)?.center ?? .tbilisiCenter,
                                       venueLabel: model.draft.venueName)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                    errorText(model.issue(.missingLocation, .outsideServiceArea))
                    Toggle(isOn: $model.draft.venueIsPublic) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("form.public_venue").font(.body.weight(.semibold))
                            Text("form.public_venue.subtitle").font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                    .tint(Theme.Palette.trust)
                    .accessibilityIdentifier("form.public")
                    errorText(model.issue(.venueNotConfirmedPublic))
                } header: { Text("form.where") } footer: {
                    Text("form.where.footer")
                }

                Section {
                    Picker(selection: $model.draft.joinPolicy) {
                        ForEach(JoinPolicy.allCases) { Text($0.title).tag($0) }
                    } label: { Text("form.join_policy") }
                    DisclosureGroup(isExpanded: $showOptional) {
                        Picker(selection: $model.draft.skillLevel) {
                            ForEach(SkillLevel.allCases) { Text($0.title).tag($0) }
                        } label: { Text("form.skill") }
                        TextField(text: $model.draft.equipment) { Text("form.equipment.placeholder") }
                        TextField(text: $model.draft.instructions, axis: .vertical) { Text("form.instructions.placeholder") }
                            .lineLimit(2...5)
                        TextField(text: $model.draft.meetingNotes, axis: .vertical) { Text("form.meeting_notes.placeholder") }
                            .lineLimit(2...4)
                        coverPicker
                        errorText(model.issue(.fieldTooLong))
                    } label: { Text("form.optional") }
                } footer: { Text("form.meeting_notes.footer") }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(model.isEditing ? "form.edit_title" : "form.create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button(model.isEditing ? "form.save" : "form.publish") {
                            Task { if let activity = await model.submit() { onDone(activity) } }
                        }
                        .bold()
                        .accessibilityIdentifier("form.submit")
                    }
                }
            }
            .interactiveDismissDisabled(model.isSubmitting)
            .alert(Text("state.error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("action.ok", role: .cancel) {}
            } message: { Text(model.error?.message ?? "") }
        }
    }

    @ViewBuilder private func errorText(_ message: String?) -> some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.danger)
        }
    }

    private var coverPicker: some View {
        PhotosPicker(selection: $coverItem, matching: .images, photoLibrary: .shared()) {
            HStack {
                Label(model.draft.coverImageData == nil ? "form.cover.add" : "form.cover.change", systemImage: "photo")
                Spacer()
                if let data = model.draft.coverImageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                }
            }
        }
        .onChange(of: coverItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self) {
                    model.draft.coverImageData = ImageProcessing.preparedJPEG(from: raw, maxDimension: 1600)
                }
            }
        }
    }
}

private struct CategoryTile: View {
    let category: ActivityCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.symbol).font(.title3.weight(.semibold))
                Text(category.title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .foregroundStyle(isSelected ? Theme.Palette.canvas : category.tint)
            .background(isSelected ? Theme.Palette.ink : category.softTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("form.category.\(category.rawValue)")
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Tap the map to set the exact meeting point. Only approved participants ever see it.
private struct MeetingPointPicker: View {
    @Binding var coordinate: Coordinate?
    let fallback: Coordinate
    var venueLabel = ""
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                if let coordinate {
                    Marker(venueLabel, systemImage: "mappin", coordinate: coordinate.clCoordinate).tint(Theme.Palette.brand)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .including([.park, .cafe, .restaurant, .library, .museum, .university])))
            .onTapGesture { point in
                if let location = proxy.convert(point, from: .local) {
                    coordinate = Coordinate(location)
                    Haptics.selection()
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text("form.map_hint")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(Theme.Spacing.s)
            }
        }
        .onAppear { recenter() }
        .onChange(of: fallback) { _, _ in recenter() }
        .accessibilityLabel(Text("form.map_accessibility"))
    }

    private func recenter() {
        let center = coordinate ?? fallback
        position = .region(MKCoordinateRegion(center: center.clCoordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
    }
}
