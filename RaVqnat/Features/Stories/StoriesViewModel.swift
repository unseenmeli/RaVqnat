import Foundation
import Observation

@MainActor
@Observable
final class StoriesViewModel {
    private(set) var groups: [StoryGroup] = []
    private(set) var isLoaded = false
    private let repository: any StoryRepository

    init(repository: any StoryRepository) { self.repository = repository }

    func load() async {
        groups = (try? await repository.storyFeed()) ?? groups
        isLoaded = true
    }

    /// Updates seen state locally right away so rings change while the viewer is open.
    func markSeen(_ story: Story) {
        guard let index = groups.firstIndex(where: { $0.activityID == story.activityID }),
              !groups[index].seenStoryIDs.contains(story.id) else { return }
        groups[index].seenStoryIDs.insert(story.id)
        Task { try? await repository.markStorySeen(story.id) }
    }

    func delete(_ story: Story) async {
        try? await repository.deleteStory(story.id)
        await load()
    }
}
