import SwiftUI

/// Horizontal story bubbles under the Explore greeting. The first bubble is "Your story".
struct StoriesRow: View {
    let groups: [StoryGroup]
    let onAdd: () -> Void
    let onOpen: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Button(action: onAdd) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.Palette.ink)
                            .frame(width: 64, height: 64)
                            .background(Theme.Palette.surfaceMuted, in: Circle())
                            .padding(3)
                        Text("stories.yours").font(.caption).foregroundStyle(Theme.Palette.inkSecondary).lineLimit(1)
                    }
                    .frame(width: 74)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stories.add")

                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    Button { onOpen(index) } label: { StoryBubble(group: group) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("stories.bubble \(group.activityTitle)"))
                        .accessibilityValue(group.hasUnseen ? Text("stories.new") : Text(verbatim: ""))
                        .accessibilityIdentifier("stories.group.\(index)")
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}

private struct StoryBubble: View {
    let group: StoryGroup

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(group.hasUnseen ? group.category.tint : Theme.Palette.surfaceStrong,
                                  lineWidth: group.hasUnseen ? 2.5 : 1.5)
                ActivityCoverArt(category: group.category, seed: group.activityID, imageURL: group.coverImageURL)
                    .frame(width: 62, height: 62)
                    .clipShape(Circle())
            }
            .frame(width: 70, height: 70)
            Text(group.activityTitle)
                .font(.caption)
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(1)
        }
        .frame(width: 74)
    }
}
