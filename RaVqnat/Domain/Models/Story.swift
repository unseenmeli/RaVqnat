import Foundation

/// Short-lived (24 h) posts attached to an activity. Only the host and approved participants
/// of an activity can post to it; anyone who can see the activity can view them.
enum StoryKind: String, Codable, Sendable { case text, photo }

/// Minimal set of backgrounds for text stories.
enum StoryBackground: String, Codable, Sendable, CaseIterable, Identifiable {
    case ink, mist, pink, sky, sage
    var id: String { rawValue }
}

struct Story: Identifiable, Hashable, Sendable {
    let id: UUID
    let activityID: UUID
    let author: UserSummary
    let kind: StoryKind
    let text: String?
    let mediaURL: URL?
    let background: StoryBackground
    let createdAt: Date
    let expiresAt: Date

    static let lifetime: TimeInterval = 24 * 3600
    static let maxTextLength = 200
}

/// All live stories of one activity, as shown by a single bubble.
struct StoryGroup: Identifiable, Hashable, Sendable {
    var id: UUID { activityID }
    let activityID: UUID
    let activityTitle: String
    let category: ActivityCategory
    let coverImageURL: URL?
    let host: UserSummary
    var stories: [Story]
    var seenStoryIDs: Set<UUID>

    var hasUnseen: Bool { stories.contains { !seenStoryIDs.contains($0.id) } }
    /// Where the viewer should start: the first unseen story, or the beginning.
    var firstUnseenIndex: Int { stories.firstIndex { !seenStoryIDs.contains($0.id) } ?? 0 }
}

struct StoryDraft: Sendable, Equatable {
    var activityID: UUID?
    var kind: StoryKind = .text
    var text = ""
    var imageData: Data?
    var background: StoryBackground = .ink

    var isValid: Bool {
        guard activityID != nil else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .text: return (1...Story.maxTextLength).contains(trimmed.count)
        case .photo: return imageData != nil && trimmed.count <= Story.maxTextLength
        }
    }
}
