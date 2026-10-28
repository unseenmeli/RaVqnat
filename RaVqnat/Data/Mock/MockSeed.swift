import Foundation

/// Fictional seed data for mock mode. All people are invented; no real identities or photos.
enum MockSeed {
    static let demoUserID = UUID(uuidString: "00000000-0000-4000-8000-0000000000AA")!

    private static func uid(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))! }
    private static func aid(_ n: Int) -> UUID { UUID(uuidString: String(format: "10000000-0000-4000-8000-%012d", n))! }

    struct SeedUser { let n: Int; let name: String; let bio: String; let interests: [String]; let verified: Bool; let hood: String }

    static let seedUsers: [SeedUser] = [
        .init(n: 1, name: "Nino K.", bio: "Guitar teacher on weekends. Coffee first, always.", interests: ["guitar", "singing", "coffee"], verified: true, hood: "vake"),
        .init(n: 2, name: "Giorgi M.", bio: "Pick-up basketball, any level. I bring the ball.", interests: ["basketball", "running"], verified: true, hood: "vake"),
        .init(n: 3, name: "Ana B.", bio: "English teacher. Let's talk about anything but grammar.", interests: ["english", "languages", "reading"], verified: true, hood: "vera"),
        .init(n: 4, name: "Luka T.", bio: "Building a startup in Tbilisi. Happy to swap notes.", interests: ["startups", "coding", "coffee"], verified: true, hood: "sololaki"),
        .init(n: 5, name: "Mariam D.", bio: "Walker, talker, Saburtalo local.", interests: ["walking", "hiking", "photography"], verified: true, hood: "saburtalo"),
        .init(n: 6, name: "Sandro G.", bio: "Chess club regular. Beginners welcome.", interests: ["chess", "board_games"], verified: true, hood: "chugureti"),
        .init(n: 7, name: "Tamar L.", bio: "Film photographer. Old Tbilisi at golden hour.", interests: ["photography", "film", "painting"], verified: true, hood: "old_tbilisi"),
        .init(n: 8, name: "Davit R.", bio: "iOS developer, occasional runner.", interests: ["coding", "design", "running"], verified: false, hood: "saburtalo"),
        .init(n: 9, name: "Elene S.", bio: "Board game collector. 200+ games and counting.", interests: ["board_games", "cooking"], verified: true, hood: "vera"),
        .init(n: 10, name: "Alex P.", bio: "New in Tbilisi, learning Georgian.", interests: ["languages", "hiking", "coffee"], verified: false, hood: "sololaki"),
        .init(n: 11, name: "Salome Ch.", bio: "Yoga and long walks.", interests: ["yoga", "walking"], verified: false, hood: "mtatsminda"),
        .init(n: 12, name: "Irakli N.", bio: "Volunteer coordinator. Always up for a hike.", interests: ["volunteering", "hiking", "cycling"], verified: true, hood: "didube"),
    ]

    struct SeedActivity {
        let n: Int; let host: Int; let title: String; let description: String; let category: ActivityCategory
        let day: Int; let hour: Int; let minute: Int; let durationHours: Double?
        let capacity: Int; let hood: String; let venue: String; let address: String; let coordinate: Coordinate
        let skill: SkillLevel; let policy: JoinPolicy; let equipment: String?; let instructions: String?
        let members: [Int]
    }

    static let seedActivities: [SeedActivity] = [
        .init(n: 1, host: 1, title: "Learn your first guitar chords", description: "I want to learn guitar — or help you learn! Bring a guitar if you have one, I'll bring a spare. We'll cover four chords and one song everyone knows.", category: .music, day: 1, hour: 17, minute: 0, durationHours: 2, capacity: 5, hood: "vake", venue: "Vake Park, main fountain", address: "Chavchavadze Ave, Vake Park", coordinate: .init(latitude: 41.7105, longitude: 44.7542), skill: .beginner, policy: .approvalRequired, equipment: "A guitar if you have one", instructions: "Look for the person with the blue guitar case.", members: [3, 10]),
        .init(n: 2, host: 2, title: "Pick-up basketball in Vake Park", description: "Anyone wanna play basketball? Casual 3-on-3, mixed levels. We rotate teams so everyone plays.", category: .sports, day: 0, hour: 19, minute: 0, durationHours: 1.5, capacity: 9, hood: "vake", venue: "Vake Park basketball courts", address: "Vake Park, lower courts", coordinate: .init(latitude: 41.7118, longitude: 44.7569), skill: .allLevels, policy: .open, equipment: "Sports shoes, water", instructions: nil, members: [8, 12, 5]),
        .init(n: 3, host: 3, title: "English conversation practice", description: "Looking for people to practice English with. Relaxed conversation over tea — topics on cards if we run out of things to say.", category: .learning, day: 2, hour: 18, minute: 30, durationHours: 1.5, capacity: 6, hood: "vera", venue: "Café on Paliashvili St.", address: "Paliashvili St, Vera", coordinate: .init(latitude: 41.7082, longitude: 44.7781), skill: .allLevels, policy: .approvalRequired, equipment: nil, instructions: "We'll sit at the big table by the window.", members: [10, 11]),
        .init(n: 4, host: 4, title: "Coffee & startup ideas", description: "Let's grab coffee and discuss startup ideas. Bring a problem you care about; leave with three people who care about it too.", category: .technology, day: 3, hour: 10, minute: 0, durationHours: 1.5, capacity: 5, hood: "sololaki", venue: "Coffee shop on Lado Asatiani St.", address: "Lado Asatiani St, Sololaki", coordinate: .init(latitude: 41.6889, longitude: 44.7995), skill: .allLevels, policy: .approvalRequired, equipment: nil, instructions: nil, members: [8]),
        .init(n: 5, host: 5, title: "Evening walk around Saburtalo", description: "Anyone wanna go for a walk? Easy pace, about 5 km, ending near the metro.", category: .outdoors, day: 1, hour: 19, minute: 30, durationHours: 1.5, capacity: 8, hood: "saburtalo", venue: "Saburtalo metro station exit", address: "Pekini Ave, Saburtalo", coordinate: .init(latitude: 41.7266, longitude: 44.7592), skill: .allLevels, policy: .open, equipment: "Comfortable shoes", instructions: nil, members: [11, 12]),
        .init(n: 6, host: 6, title: "Chess for beginners", description: "I'm learning chess and looking for other beginners. We'll play slow games and talk through moves. No ratings, no pressure.", category: .games, day: 4, hour: 16, minute: 0, durationHours: 2, capacity: 6, hood: "chugureti", venue: "Fabrika courtyard", address: "Egnate Ninoshvili St, Chugureti", coordinate: .init(latitude: 41.7093, longitude: 44.8031), skill: .beginner, policy: .approvalRequired, equipment: "Boards provided", instructions: nil, members: [9]),
        .init(n: 7, host: 7, title: "Photography walk in Old Tbilisi", description: "Let's organise a small photography walk through the old town at golden hour. Phones are perfect cameras.", category: .arts, day: 5, hour: 18, minute: 0, durationHours: 2, capacity: 6, hood: "old_tbilisi", venue: "Meidan Square", address: "Meidan Square, Old Tbilisi", coordinate: .init(latitude: 41.6890, longitude: 44.8085), skill: .allLevels, policy: .approvalRequired, equipment: "Any camera or phone", instructions: nil, members: [5, 10]),
        .init(n: 8, host: 9, title: "Board game night", description: "Friendly board games — Codenames, Ticket to Ride and quick party games. I'll teach every game.", category: .games, day: 2, hour: 19, minute: 0, durationHours: 3, capacity: 8, hood: "vera", venue: "Board game café, Vera", address: "Kostava St, Vera", coordinate: .init(latitude: 41.7050, longitude: 44.7830), skill: .beginner, policy: .approvalRequired, equipment: nil, instructions: nil, members: [6, 3, 8]),
        .init(n: 9, host: 12, title: "Morning hike to Turtle Lake", description: "Short hike up to Turtle Lake and back through the forest trail. Moderate pace, coffee at the top.", category: .outdoors, day: 6, hour: 9, minute: 0, durationHours: 3, capacity: 10, hood: "vake", venue: "Turtle Lake cable car, lower station", address: "Chavchavadze Ave end, Vake", coordinate: .init(latitude: 41.7012, longitude: 44.7514), skill: .intermediate, policy: .open, equipment: "Hiking shoes, water", instructions: nil, members: [2, 5, 11, 10]),
        .init(n: 10, host: 3, title: "Georgian–English language exchange", description: "Half the time in Georgian, half in English. Perfect if you're new to Tbilisi or want to practise your English.", category: .learning, day: 3, hour: 19, minute: 0, durationHours: 2, capacity: 10, hood: "chugureti", venue: "Fabrika common area", address: "Egnate Ninoshvili St, Chugureti", coordinate: .init(latitude: 41.7096, longitude: 44.8027), skill: .allLevels, policy: .open, equipment: nil, instructions: nil, members: [10, 11, 4]),
        .init(n: 11, host: 4, title: "SwiftUI study group", description: "Building iOS apps? Let's code together for two hours and review each other's work. Bring a laptop.", category: .technology, day: 7, hour: 15, minute: 0, durationHours: 2, capacity: 6, hood: "saburtalo", venue: "Co-working space, Saburtalo", address: "Vazha-Pshavela Ave, Saburtalo", coordinate: .init(latitude: 41.7254, longitude: 44.7470), skill: .intermediate, policy: .approvalRequired, equipment: "Laptop with Xcode", instructions: nil, members: [8]),
        .init(n: 12, host: 7, title: "Sketching at the Dry Bridge", description: "Sketch the Dry Bridge market and river. All mediums welcome; I'll bring extra pencils.", category: .arts, day: 8, hour: 12, minute: 0, durationHours: 2, capacity: 6, hood: "mtatsminda", venue: "Dry Bridge market", address: "Dry Bridge, Mtatsminda", coordinate: .init(latitude: 41.6985, longitude: 44.8032), skill: .beginner, policy: .approvalRequired, equipment: "Sketchbook", instructions: nil, members: []),
        .init(n: 13, host: 1, title: "Khinkali tasting & chat", description: "Food and coffee lovers: let's try a classic khinkali place and talk about our favourite spots in the city.", category: .food, day: 4, hour: 14, minute: 0, durationHours: 1.5, capacity: 4, hood: "sololaki", venue: "Restaurant on Leselidze St.", address: "Kote Afkhazi St, Sololaki", coordinate: .init(latitude: 41.6918, longitude: 44.8044), skill: .allLevels, policy: .approvalRequired, equipment: nil, instructions: "Everyone pays for their own meal.", members: [10, 4, 5, 3]),
        .init(n: 14, host: 12, title: "Park clean-up volunteers", description: "One hour of picking up litter in Mziuri park, then tea. Gloves and bags provided.", category: .other, day: 9, hour: 11, minute: 0, durationHours: 1, capacity: 15, hood: "vake", venue: "Mziuri park entrance", address: "Mziuri Park, Vake", coordinate: .init(latitude: 41.7158, longitude: 44.7628), skill: .allLevels, policy: .open, equipment: nil, instructions: nil, members: [5, 11]),
    ]

    static let seedChat: [(activity: Int, user: Int, body: String, minutesAgo: Int)] = [
        (1, 1, "Hi everyone! Looking forward to Saturday 🎸", 300),
        (1, 3, "Me too! I only know one chord so far 😅", 280),
        (1, 1, "Perfect, that's one more than most people start with.", 270),
        (2, 2, "Court is booked from 19:00. See you there!", 120),
        (2, 12, "I'll bring a second ball.", 90),
        (3, 3, "Tea is on me for the first round.", 60),
        (8, 9, "I'm bringing Codenames and Ticket to Ride.", 200),
        (8, 6, "Nice! Can we try Azul as well?", 150),
        (9, 12, "Weather looks great for Saturday ☀️", 400),
        (13, 1, "Table is reserved under 'RaVqnat'.", 500),
    ]

    /// Text stories (no photos of people in seed data).
    static let seedStories: [(activity: Int, user: Int, text: String, background: StoryBackground, minutesAgo: Int)] = [
        (2, 2, "Court is booked from 19:00 🏀\nStill 6 spots — come play!", .ink, 40),
        (2, 12, "Bringing a second ball. Beginners very welcome.", .sky, 25),
        (1, 1, "I'll have a spare guitar 🎸\nNo experience needed.", .pink, 90),
        (8, 9, "Tonight's line-up: Codenames, Ticket to Ride, Azul 🎲", .sage, 120),
        (9, 12, "Forecast: sunny ☀️ Meet at the lower cable car station.", .mist, 200),
        (7, 7, "Golden hour starts around 18:40. Phones are perfect cameras.", .ink, 300),
    ]

    static let simulatedReplies = [
        "Sounds great, see you there!",
        "👍",
        "Thanks for the update!",
        "Looking forward to it.",
    ]

    static func makeState(now: Date = .now) -> MockState {
        var state = MockState()
        let calendar = ActivityTime.calendar()
        let startOfToday = calendar.startOfDay(for: now)

        for seed in seedUsers {
            let id = uid(seed.n)
            state.users[id] = .init(
                id: id, displayName: seed.name, bio: seed.bio, avatarURL: nil, interestIDs: seed.interests,
                preferredLanguage: .ka, homeNeighborhoodID: seed.hood, onboardingCompleted: true,
                ageAssurance: .selfDeclared,
                verification: seed.verified
                    ? .init(status: .verified, verifiedAt: now.addingTimeInterval(-86_400 * 30), expiresAt: now.addingTimeInterval(86_400 * 335), provider: "mock")
                    : .unverified,
                restrictions: .none,
                memberSince: now.addingTimeInterval(-86_400 * Double(30 + seed.n * 7))
            )
        }

        for seed in seedActivities {
            let id = aid(seed.n)
            var start = calendar.date(bySettingHour: seed.hour, minute: seed.minute, second: 0,
                                      of: calendar.date(byAdding: .day, value: seed.day, to: startOfToday)!)!
            if start < now.addingTimeInterval(3600) { start = start.addingTimeInterval(86_400) }
            state.activities[id] = .init(
                id: id, hostID: uid(seed.host), title: seed.title, description: seed.description,
                category: seed.category, startsAt: start,
                endsAt: seed.durationHours.map { start.addingTimeInterval($0 * 3600) },
                timeZoneID: ActivityTime.defaultTimeZoneID, capacity: seed.capacity,
                neighborhoodID: seed.hood, approxCoordinate: LocationPrivacy.approximate(seed.coordinate),
                status: .published, joinPolicy: seed.policy, skillLevel: seed.skill,
                equipment: seed.equipment, instructions: seed.instructions, coverImageURL: nil,
                createdAt: now.addingTimeInterval(-86_400), updatedAt: now.addingTimeInterval(-86_400),
                clientRequestID: nil, venueName: seed.venue, address: seed.address,
                exactCoordinate: seed.coordinate, meetingNotes: nil
            )
            for member in seed.members {
                state.members.append(.init(activityID: id, userID: uid(member), state: .approved, note: nil,
                                           requestedAt: now.addingTimeInterval(-7200), updatedAt: now.addingTimeInterval(-7000)))
            }
        }

        for (index, story) in seedStories.enumerated() {
            let created = now.addingTimeInterval(-Double(story.minutesAgo) * 60)
            state.stories.append(.init(
                id: UUID(uuidString: String(format: "30000000-0000-4000-8000-%012d", index + 1))!,
                activityID: aid(story.activity), authorID: uid(story.user), kind: .text, text: story.text, mediaURL: nil,
                background: story.background, createdAt: created, expiresAt: created.addingTimeInterval(Story.lifetime)))
        }

        for (index, message) in seedChat.enumerated() {
            state.messages.append(.init(
                id: UUID(uuidString: String(format: "20000000-0000-4000-8000-%012d", index + 1))!,
                activityID: aid(message.activity), senderID: uid(message.user), body: message.body,
                createdAt: now.addingTimeInterval(-Double(message.minutesAgo) * 60), clientMessageID: nil))
        }
        return state
    }

    static func demoUser(now: Date = .now, onboarded: Bool) -> MockState.User {
        .init(id: demoUserID, displayName: onboarded ? "Meli" : "", bio: "", avatarURL: nil,
              interestIDs: onboarded ? ["coffee", "chess"] : [], preferredLanguage: .en,
              homeNeighborhoodID: onboarded ? "vake" : nil, onboardingCompleted: onboarded,
              ageAssurance: onboarded ? .selfDeclared : .none, verification: .unverified,
              restrictions: .none, memberSince: now)
    }
}
