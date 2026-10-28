import Foundation

enum ActivityCategory: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case music, sports, learning, technology, food, arts, outdoors, games, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: String(localized: "category.music")
        case .sports: String(localized: "category.sports")
        case .learning: String(localized: "category.learning")
        case .technology: String(localized: "category.technology")
        case .food: String(localized: "category.food")
        case .arts: String(localized: "category.arts")
        case .outdoors: String(localized: "category.outdoors")
        case .games: String(localized: "category.games")
        case .other: String(localized: "category.other")
        }
    }

    var symbol: String {
        switch self {
        case .music: "music.note"
        case .sports: "figure.basketball"
        case .learning: "book.fill"
        case .technology: "laptopcomputer"
        case .food: "cup.and.saucer.fill"
        case .arts: "paintpalette.fill"
        case .outdoors: "leaf.fill"
        case .games: "puzzlepiece.fill"
        case .other: "sparkles"
        }
    }

    /// Secondary symbols used to compose procedural cover art.
    var decorativeSymbols: [String] {
        switch self {
        case .music: ["music.note.list", "music.mic", "pianokeys", "music.quarternote.3", "headphones"]
        case .sports: ["basketball.fill", "soccerball", "tennis.racket", "figure.run", "volleyball.fill"]
        case .learning: ["character.book.closed.fill", "graduationcap.fill", "text.bubble.fill", "lightbulb.fill", "globe.europe.africa.fill"]
        case .technology: ["chevron.left.forwardslash.chevron.right", "cpu.fill", "iphone", "keyboard.fill", "network"]
        case .food: ["fork.knife", "mug.fill", "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill", "carrot.fill"]
        case .arts: ["camera.fill", "theatermasks.fill", "paintbrush.pointed.fill", "pencil.and.scribble", "photo.artframe"]
        case .outdoors: ["mountain.2.fill", "sun.max.fill", "bicycle", "tree.fill", "figure.hiking"]
        case .games: ["checkerboard.rectangle", "dice.fill", "gamecontroller.fill", "suit.club.fill", "flag.checkered"]
        case .other: ["star.fill", "heart.fill", "bubble.left.and.bubble.right.fill", "hand.wave.fill", "balloon.2.fill"]
        }
    }
}

struct Interest: Identifiable, Hashable, Sendable {
    let id: String
    let category: ActivityCategory

    var title: String { L10n.dynamic("interest.\(id)") }

    static let all: [Interest] = [
        .init(id: "guitar", category: .music), .init(id: "singing", category: .music),
        .init(id: "basketball", category: .sports), .init(id: "football", category: .sports),
        .init(id: "running", category: .sports), .init(id: "tennis", category: .sports),
        .init(id: "yoga", category: .sports),
        .init(id: "english", category: .learning), .init(id: "languages", category: .learning),
        .init(id: "reading", category: .learning),
        .init(id: "coding", category: .technology), .init(id: "startups", category: .technology),
        .init(id: "design", category: .technology),
        .init(id: "coffee", category: .food), .init(id: "cooking", category: .food),
        .init(id: "photography", category: .arts), .init(id: "painting", category: .arts),
        .init(id: "film", category: .arts),
        .init(id: "hiking", category: .outdoors), .init(id: "cycling", category: .outdoors),
        .init(id: "walking", category: .outdoors),
        .init(id: "chess", category: .games), .init(id: "board_games", category: .games),
        .init(id: "volunteering", category: .other),
    ]

    static func find(_ id: String) -> Interest? { all.first { $0.id == id } }
}
