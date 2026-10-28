import SwiftUI

/// All filters in one friendly sheet: when, what, where and a couple of extras.
struct FilterSheet: View {
    let onApply: (ExploreFilters) -> Void
    @State private var filters: ExploreFilters
    @State private var pickedDays: Set<DateComponents>
    @Environment(\.dismiss) private var dismiss

    init(initial: ExploreFilters, onApply: @escaping (ExploreFilters) -> Void) {
        self.onApply = onApply
        _filters = State(initialValue: initial)
        _pickedDays = State(initialValue: Set(initial.customDays.compactMap(FilterSheet.components(from:))))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    whenSection
                    whatSection
                    whereSection
                    extrasSection
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle(Text("explore.filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text("action.close"))
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    // MARK: Sections

    private var whenSection: some View {
        FilterSection(title: "filter.section.date", subtitle: "filter.section.date.subtitle") {
            FlowLayout(spacing: Theme.Spacing.s) {
                ForEach(DateFilter.allCases) { option in
                    FilterChip(title: option.title, symbol: option.symbol, isSelected: filters.date == option) {
                        withAnimation(.spring(duration: 0.3)) { filters.date = option }
                    }
                    .accessibilityIdentifier("filter.date.\(option.rawValue)")
                }
            }
            if filters.date == .custom {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    MultiDatePicker(selection: $pickedDays, in: datesRange) {
                        Text("filter.date.custom")
                    }
                    .tint(Theme.Palette.ink)
                    .environment(\.calendar, ActivityTime.calendar())
                    .onChange(of: pickedDays) { _, days in
                        filters.customDays = Set(days.compactMap(FilterSheet.key(from:)))
                    }
                    Text(filters.customDays.isEmpty ? String(localized: "filter.days_hint")
                         : String(localized: "filter.days_selected \(filters.customDays.count)"))
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                        .accessibilityIdentifier("filter.days_hint")
                }
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var whatSection: some View {
        FilterSection(title: "filter.section.category", subtitle: "filter.section.category.subtitle") {
            FlowLayout(spacing: Theme.Spacing.s) {
                ForEach(ActivityCategory.allCases) { category in
                    FilterChip(title: category.title, symbol: category.symbol, isSelected: filters.categories.contains(category)) {
                        if filters.categories.contains(category) { filters.categories.remove(category) } else { filters.categories.insert(category) }
                    }
                    .accessibilityIdentifier("filter.category.\(category.rawValue)")
                }
            }
        }
    }

    private var whereSection: some View {
        FilterSection(title: "filter.section.neighborhood", subtitle: "filter.section.neighborhood.subtitle") {
            FlowLayout(spacing: Theme.Spacing.s) {
                FilterChip(title: String(localized: "explore.all_tbilisi"), symbol: "globe", isSelected: filters.area == .anywhere) {
                    filters.area = .anywhere
                }
                FilterChip(title: String(localized: "explore.near_me"), symbol: "location.fill", isSelected: filters.area == .nearMe) {
                    filters.area = .nearMe
                }
                .accessibilityIdentifier("filter.near_me")
                ForEach(Neighborhood.all) { hood in
                    FilterChip(title: hood.name, isSelected: filters.area == .neighborhood(hood.id)) {
                        filters.area = .neighborhood(hood.id)
                    }
                    .accessibilityIdentifier("filter.area.\(hood.id)")
                }
            }
            if filters.area == .nearMe {
                Label("filter.near_me.note", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    private var extrasSection: some View {
        FilterSection(title: "filter.section.extras", subtitle: nil) {
            VStack(spacing: 0) {
                ToggleRow(symbol: "person.badge.plus", title: "filter.has_spots", subtitle: "filter.has_spots.subtitle",
                          isOn: $filters.onlyWithSpots)
                Divider().padding(.leading, 52)
                ToggleRow(symbol: "leaf", title: "filter.beginner", subtitle: "filter.beginner.subtitle",
                          isOn: $filters.beginnerFriendly)
            }
            .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: Theme.Spacing.l) {
            Button("filter.clear_all") {
                withAnimation { filters = ExploreFilters(); pickedDays = [] }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(filters.isEmpty ? Theme.Palette.inkTertiary : Theme.Palette.ink)
            .disabled(filters.isEmpty)
            Button("filter.show") {
                onApply(filters)
                dismiss()
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("filter.apply")
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Palette.canvas.ignoresSafeArea())
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Dates

    private var datesRange: Range<Date> {
        let calendar = ActivityTime.calendar()
        let start = calendar.startOfDay(for: .now)
        return start..<calendar.date(byAdding: .day, value: 61, to: start)!
    }

    static func key(from components: DateComponents) -> String? {
        guard let y = components.year, let m = components.month, let d = components.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func components(from key: String) -> DateComponents? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents(calendar: ActivityTime.calendar(), year: parts[0], month: parts[1], day: parts[2])
        components.calendar = ActivityTime.calendar()
        return components
    }
}

private struct FilterSection<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Theme.Palette.inkSecondary) }
            }
            content
        }
    }
}

private struct ToggleRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold))
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
        .tint(Theme.Palette.ink)
        .padding(Theme.Spacing.l)
    }
}

struct NeighborhoodPickerSheet: View {
    let selected: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button { onSelect(nil); dismiss() } label: {
                    row(String(localized: "explore.all_tbilisi"), selected == nil)
                }
                ForEach(Neighborhood.all) { hood in
                    Button { onSelect(hood.id); dismiss() } label: { row(hood.name, selected == hood.id) }
                }
            }
            .navigationTitle(Text("explore.choose_neighborhood"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, _ isSelected: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.Palette.ink)
            Spacer()
            if isSelected { Image(systemName: "checkmark").foregroundStyle(Theme.Palette.ink) }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
