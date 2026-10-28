import SwiftUI

/// Capsule filter chip: soft grey, solid ink when selected.
struct FilterChip: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.Palette.ink
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.footnote.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.Palette.canvas : tint)
                }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.l)
            .frame(minHeight: 38)
            .foregroundStyle(isSelected ? Theme.Palette.canvas : Theme.Palette.ink)
            .background(isSelected ? Theme.Palette.ink : Theme.Palette.surfaceMuted, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Category label laid over cover images.
struct CategoryTag: View {
    let category: ActivityCategory
    var onDark = false

    var body: some View {
        Label {
            Text(category.title)
        } icon: {
            Image(systemName: category.symbol).foregroundStyle(category.tint)
        }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(Theme.Palette.ink)
            .background(.thinMaterial, in: Capsule())
    }
}

/// Small status capsule, e.g. "3 spots left", "Requested".
struct StatusPill: View {
    let text: String
    var symbol: String?
    var tint: Color = Theme.Palette.ink
    var background: Color = Theme.Palette.surfaceMuted
    var inverted = false
    var symbolTint: Color?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)).foregroundStyle(symbolTint ?? (inverted ? Theme.Palette.canvas : tint)) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(inverted ? Theme.Palette.canvas : tint)
        .background(inverted ? Theme.Palette.ink : background, in: Capsule())
    }
}

/// Wrapping layout for interest chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = Theme.Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                                           proposal: ProposedViewSize(item.size))
            }
        }
    }

    private struct Row { var items: [(index: Int, x: CGFloat, size: CGSize)] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].items.isEmpty {
                let previous = rows[rows.count - 1]
                rows.append(Row(y: previous.y + previous.height + spacing))
                x = 0
            }
            rows[rows.count - 1].items.append((index, x, size))
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += size.width + spacing
            rows[rows.count - 1].width = x - spacing
        }
        return rows
    }
}
