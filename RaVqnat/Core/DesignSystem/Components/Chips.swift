import SwiftUI

/// Bordered tag that inverts to solid ink when selected.
struct FilterChip: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.Palette.ink
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
                Text(title).lineLimit(1)
            }
            .rvLabelStyle(.rvCaption.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.m)
            .frame(minHeight: 36)
            .foregroundStyle(isSelected ? Theme.Palette.canvas : Theme.Palette.ink)
            .background(isSelected ? Theme.Palette.ink : Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small)
                .strokeBorder(Theme.Palette.ink.opacity(isSelected ? 1 : 0.85), lineWidth: Theme.Stroke.hairline))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.Palette.accent).offset(x: 3, y: 3)
                }
            }
            .padding(.trailing, 3).padding(.bottom, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

struct CategoryTag: View {
    let category: ActivityCategory
    var onDark = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.symbol).font(.caption2.weight(.bold))
            Text(category.title)
        }
        .rvLabelStyle(.rvCaption.weight(.bold))
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 5)
        .foregroundStyle(Theme.Palette.ink)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.hairline))
    }
}

/// Small monospaced status tag, e.g. "3 SPOTS LEFT", "REQUESTED".
struct StatusPill: View {
    let text: String
    var symbol: String?
    var tint: Color = Theme.Palette.ink
    var background: Color = Theme.Palette.surfaceMuted
    var inverted = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2.weight(.bold)) }
            Text(text)
        }
        .rvLabelStyle(.rvCaption.weight(.semibold))
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 5)
        .foregroundStyle(inverted ? Theme.Palette.canvas : tint)
        .background(inverted ? Theme.Palette.ink : background, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
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
