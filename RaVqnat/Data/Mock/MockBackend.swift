import Foundation

/// In-memory backend used when no Supabase project is configured, in previews and in tests.
///
/// It implements every repository protocol and enforces the same business rules as the
/// Postgres functions (membership state machine, capacity, blocking, eligibility, rate limits),
/// using the shared domain services. It also simulates the "other side" of the product
/// (hosts approving requests, people requesting to join your activity) so every flow can be
/// experienced end to end. Simulation is clearly limited to mock mode.
actor MockBackend {
    struct Options: Sendable {
        var persistenceURL: URL?
        var simulateOtherUsers = true
        var simulationDelay: Duration = .seconds(3)
        var now: @Sendable () -> Date = { .now }
    }

    private var state: MockState
    private let options: Options
    private var liveContinuations: [UUID: [UUID: AsyncStream<ChatMessage>.Continuation]] = [:]
    private var rateEvents: [String: [Date]] = [:]
    private var pendingVerification = false

    init(state: MockState? = nil, options: Options = Options()) {
        self.options = options
        if let state {
            self.state = state
        } else if let url = options.persistenceURL, let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(MockState.self, from: data) {
            self.state = decoded
        } else {
            self.state = MockSeed.makeState(now: options.now())
        }
    }

    static func defaultPersistenceURL() -> URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("mock-backend.json")
    }

    // MARK: - Helpers

    private var now: Date { options.now() }

    private func persist() {
        guard let url = options.persistenceURL else { return }
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Log.app.error("Mock state persistence failed")
        }
    }

    private func requireUser() throws(AppError) -> MockState.User {
        guard let id = state.currentUserID, let user = state.users[id] else { throw .unauthorized }
        return user
    }

    private func requireActiveUser() throws(AppError) -> MockState.User {
        let user = try requireUser()
        if user.restrictions.isSuspended(at: now) { throw .rule(.accountSuspended) }
        if !user.onboardingCompleted { throw .rule(.onboardingIncomplete) }
        return user
    }

    private func isBlocked(_ a: UUID, _ b: UUID) -> Bool {
        state.blocks.contains { ($0.blockerID == a && $0.blockedID == b) || ($0.blockerID == b && $0.blockedID == a) }
    }

    private func checkRate(_ action: String, userID: UUID, limit: Int, window: TimeInterval) throws(AppError) {
        let key = "\(action)|\(userID)"
        let cutoff = now.addingTimeInterval(-window)
        var events = (rateEvents[key] ?? []).filter { $0 > cutoff }
        guard events.count < limit else { throw .rateLimited }
        events.append(now)
        rateEvents[key] = events
    }

    private func summary(_ id: UUID?) -> UserSummary {
        guard let id, let user = state.users[id] else {
            return UserSummary(id: id ?? UUID(), displayName: String(localized: "user.deleted"), avatarURL: nil, isVerified: false)
        }
        return UserSummary(id: user.id, displayName: user.displayName, avatarURL: user.avatarURL,
                           isVerified: user.verification.isCurrentlyVerified(at: now))
    }

    private func approvedCount(_ activityID: UUID) -> Int {
        state.members.filter { $0.activityID == activityID && $0.state.occupiesSpot }.count
    }

    private func memberIndex(_ activityID: UUID, _ userID: UUID) -> Int? {
        state.members.firstIndex { $0.activityID == activityID && $0.userID == userID }
    }

    private func makeActivity(_ row: MockState.ActivityRow, viewer: UUID?, origin: Coordinate? = nil) -> Activity {
        Activity(
            id: row.id, host: summary(row.hostID), title: row.title, description: row.description,
            category: row.category, startsAt: row.startsAt, endsAt: row.endsAt, timeZoneID: row.timeZoneID,
            capacity: row.capacity, approvedCount: approvedCount(row.id), neighborhoodID: row.neighborhoodID,
            approxCoordinate: row.approxCoordinate, status: row.status, joinPolicy: row.joinPolicy,
            skillLevel: row.skillLevel, equipment: row.equipment, instructions: row.instructions,
            coverImageURL: row.coverImageURL, createdAt: row.createdAt,
            myMembership: viewer.flatMap { v in memberIndex(row.id, v).map { state.members[$0].state } },
            distanceMeters: origin.map { row.approxCoordinate.distance(to: $0) }
        )
    }

    private func isParticipant(_ row: MockState.ActivityRow, _ userID: UUID) -> Bool {
        if row.hostID == userID { return true }
        guard let index = memberIndex(row.id, userID) else { return false }
        return state.members[index].state.occupiesSpot
    }

    private func visibleActivity(_ id: UUID, for userID: UUID) throws(AppError) -> MockState.ActivityRow {
        guard let row = state.activities[id], row.status != .removed else { throw .notFound }
        if row.hostID != userID && isBlocked(row.hostID, userID) { throw .notFound }
        return row
    }

    private func transition(_ activityID: UUID, _ userID: UUID, to newState: MembershipState,
                            actor: MembershipStateMachine.Actor, note: String? = nil) throws(AppError) {
        guard let row = state.activities[activityID] else { throw .notFound }
        let index = memberIndex(activityID, userID)
        let current = index.map { state.members[$0].state }
        try MembershipStateMachine.validate(from: current, to: newState, actor: actor,
                                            approvedCount: approvedCount(activityID), capacity: row.capacity)
        if let index {
            state.members[index].state = newState
            state.members[index].updatedAt = now
            if let note { state.members[index].note = note }
        } else {
            state.members.append(.init(activityID: activityID, userID: userID, state: newState, note: note,
                                       requestedAt: now, updatedAt: now))
        }
    }

    /// Blocks must not end up sharing an activity: the requester can't join if they have a block
    /// relationship with the host or any approved participant.
    private func hasBlockConflict(activity: MockState.ActivityRow, userID: UUID) -> Bool {
        if isBlocked(activity.hostID, userID) { return true }
        return state.members.contains {
            $0.activityID == activity.id && $0.state.occupiesSpot && $0.userID != userID && isBlocked($0.userID, userID)
        }
    }

    // MARK: - Test & simulation hooks

    func snapshot() -> MockState { state }

    func setCurrentUser(_ id: UUID?) { state.currentUserID = id }

    func upsertUser(_ user: MockState.User) {
        state.users[user.id] = user
        persist()
    }

    private func scheduleSimulation(_ work: @escaping @Sendable (isolated MockBackend) -> Void, after delay: Duration? = nil) {
        guard options.simulateOtherUsers else { return }
        let delay = delay ?? options.simulationDelay
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            await self.runSimulation(work)
        }
    }

    private func runSimulation(_ work: @Sendable (isolated MockBackend) -> Void) {
        work(self)
        persist()
    }

    private func simulateHostDecision(activityID: UUID, userID: UUID) {
        guard let index = memberIndex(activityID, userID), state.members[index].state == .pending,
              let row = state.activities[activityID], !hasBlockConflict(activity: row, userID: userID) else { return }
        try? transition(activityID, userID, to: .approved, actor: .host)
    }

    private func simulateJoinRequests(activityID: UUID) {
        guard let row = state.activities[activityID] else { return }
        let candidates = MockSeed.seedUsers.map { UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", $0.n))! }
            .filter { $0 != row.hostID && memberIndex(activityID, $0) == nil && !isBlocked($0, row.hostID) }
            .prefix(2)
        let notes = ["Hi! I'd love to join.", "Is it okay if I'm a complete beginner?"]
        for (offset, id) in candidates.enumerated() {
            state.members.append(.init(activityID: activityID, userID: id, state: .pending, note: notes[offset % notes.count],
                                       requestedAt: now, updatedAt: now))
        }
    }

    private func simulateReply(activityID: UUID, excluding userID: UUID) {
        guard let row = state.activities[activityID] else { return }
        let others = ([row.hostID] + state.members.filter { $0.activityID == activityID && $0.state.occupiesSpot }.map(\.userID))
            .filter { $0 != userID && !isBlocked($0, userID) }
        guard let sender = others.first else { return }
        let body = MockSeed.simulatedReplies[state.messages.count % MockSeed.simulatedReplies.count]
        let message = MockState.MessageRow(id: UUID(), activityID: activityID, senderID: sender, body: body,
                                           createdAt: now, clientMessageID: nil)
        state.messages.append(message)
        broadcast(message)
    }

    /// Delivers a new message to live listeners, hiding it when sender and viewer have a block
    /// relationship (mirrors the RLS policy on `activity_messages`).
    private func broadcast(_ row: MockState.MessageRow) {
        guard let viewer = state.currentUserID, !isBlocked(row.senderID ?? viewer, viewer) else { return }
        let message = makeMessage(row)
        for (_, continuation) in liveContinuations[row.activityID] ?? [:] {
            continuation.yield(message)
        }
    }

    private func makeMessage(_ row: MockState.MessageRow) -> ChatMessage {
        ChatMessage(id: row.id, activityID: row.activityID, sender: summary(row.senderID), body: row.body,
                    createdAt: row.createdAt, clientMessageID: row.clientMessageID)
    }

    private func addContinuation(_ continuation: AsyncStream<ChatMessage>.Continuation, activityID: UUID, token: UUID) {
        liveContinuations[activityID, default: [:]][token] = continuation
    }

    private func removeContinuation(activityID: UUID, token: UUID) {
        liveContinuations[activityID]?[token] = nil
    }
}

// MARK: - AuthRepository

extension MockBackend: AuthRepository {
    nonisolated var supportsDemoSignIn: Bool { true }

    func restoreSession() async -> AuthSession? {
        guard let id = state.currentUserID, state.users[id] != nil else { return nil }
        return AuthSession(userID: id)
    }

    /// Mock mode accepts a real Apple credential but does not verify it with a server; it maps the
    /// sign-in to the local demo account.
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AuthSession {
        try await signInAsDemoUser()
    }

    func signInAsDemoUser() async throws -> AuthSession {
        if state.users[MockSeed.demoUserID] == nil {
            state.users[MockSeed.demoUserID] = MockSeed.demoUser(now: now, onboarded: false)
        }
        state.currentUserID = MockSeed.demoUserID
        persist()
        return AuthSession(userID: MockSeed.demoUserID)
    }

    func signOut() async throws {
        state.currentUserID = nil
        persist()
    }

    /// Mirrors `public.prepare_account_deletion` + auth user deletion (see docs/SECURITY.md, retention).
    func deleteAccount() async throws {
        let user = try requireUser()
        let id = user.id
        for (activityID, row) in state.activities where row.hostID == id && row.startsAt > now && row.status == .published {
            state.activities[activityID]?.status = .cancelled
        }
        state.members.removeAll { $0.userID == id }
        for index in state.messages.indices where state.messages[index].senderID == id {
            state.messages[index].senderID = nil
            state.messages[index].body = ""
        }
        state.messages.removeAll { $0.senderID == nil && $0.body.isEmpty }
        state.blocks.removeAll { $0.blockerID == id || $0.blockedID == id }
        state.feedback.removeAll { $0.reviewerID == id }
        for index in state.reports.indices {
            if state.reports[index].reporterID == id { state.reports[index].reporterID = nil }
        }
        state.deviceTokens = state.deviceTokens.filter { $0.value != id }
        state.preferences[id] = nil
        state.readState = state.readState.filter { !$0.key.hasSuffix("|\(id)") }
        state.users[id] = nil
        state.currentUserID = nil
        persist()
    }
}

// MARK: - ProfileRepository

extension MockBackend: ProfileRepository {
    private func makeMyProfile(_ user: MockState.User) -> MyProfile {
        MyProfile(id: user.id, displayName: user.displayName, bio: user.bio, avatarURL: user.avatarURL,
                  interestIDs: user.interestIDs, preferredLanguage: user.preferredLanguage,
                  homeNeighborhoodID: user.homeNeighborhoodID, onboardingCompleted: user.onboardingCompleted,
                  ageAssurance: user.ageAssurance, verification: user.verification,
                  restrictions: user.restrictions, memberSince: user.memberSince)
    }

    func myProfile() async throws -> MyProfile {
        makeMyProfile(try requireUser())
    }

    func completeOnboarding(_ submission: OnboardingSubmission) async throws -> MyProfile {
        var user = try requireUser()
        let issues = OnboardingValidator.issues(for: submission)
        if issues.contains(.notAdult) { throw AppError.rule(.ageRequirement) }
        guard issues.isEmpty else { throw AppError.rule(.invalidInput) }
        user.displayName = OnboardingValidator.normalizedName(submission.displayName)
        user.interestIDs = submission.interestIDs.filter { Interest.find($0) != nil }
        user.preferredLanguage = submission.preferredLanguage
        user.homeNeighborhoodID = submission.homeNeighborhoodID
        user.ageAssurance = user.ageAssurance == .verified ? .verified : .selfDeclared
        user.onboardingCompleted = true
        state.users[user.id] = user
        persist()
        return makeMyProfile(user)
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> MyProfile {
        var user = try requireUser()
        guard OnboardingValidator.nameIssue(update.displayName) == nil,
              update.bio.count <= OnboardingValidator.bioLimit,
              update.interestIDs.count <= OnboardingValidator.maxInterests else { throw AppError.rule(.invalidInput) }
        user.displayName = OnboardingValidator.normalizedName(update.displayName)
        user.bio = update.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        user.interestIDs = update.interestIDs.filter { Interest.find($0) != nil }
        user.preferredLanguage = update.preferredLanguage
        user.homeNeighborhoodID = update.homeNeighborhoodID
        state.users[user.id] = user
        persist()
        return makeMyProfile(user)
    }

    func uploadAvatar(jpegData: Data) async throws -> MyProfile {
        var user = try requireUser()
        guard jpegData.count <= 5 * 1024 * 1024 else { throw AppError.rule(.invalidInput) }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mock-avatars", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(user.id)-\(UUID().uuidString).jpg")
        try jpegData.write(to: url, options: .atomic)
        user.avatarURL = url
        state.users[user.id] = user
        persist()
        return makeMyProfile(user)
    }

    func profile(id: UUID) async throws -> PublicProfile {
        let me = try requireUser()
        guard let user = state.users[id], !isBlocked(me.id, id) || id == me.id else { throw AppError.notFound }
        let hosted = state.activities.values.filter { $0.hostID == id && $0.status != .removed }.count
        return PublicProfile(id: user.id, displayName: user.displayName, bio: user.bio, avatarURL: user.avatarURL,
                             interestIDs: user.interestIDs, isVerified: user.verification.isCurrentlyVerified(at: now),
                             memberSince: user.memberSince, hostedActivityCount: hosted)
    }

    func trustPolicy() async throws -> TrustPolicy { .launch }
}

// MARK: - ActivityRepository

extension MockBackend: ActivityRepository {
    func nearbyActivities(_ query: ActivityQuery, cursor: Int?, pageSize: Int) async throws -> Page<Activity> {
        let me = try requireUser()
        let interval = query.date.interval(now: now)
        let rows = state.activities.values
            .filter { row in
                row.status == .published
                    && (row.endsAt ?? row.startsAt.addingTimeInterval(7200)) > now
                    && !isBlocked(row.hostID, me.id)
                    && row.approxCoordinate.distance(to: query.origin) <= query.radiusMeters
                    && (query.categories.isEmpty || query.categories.contains(row.category))
                    && (query.neighborhoodID == nil || row.neighborhoodID == query.neighborhoodID)
                    && (!query.onlyWithSpots || approvedCount(row.id) < row.capacity)
                    && (!query.beginnerFriendly || row.skillLevel == .beginner || row.skillLevel == .allLevels)
                    && (interval.map { $0.contains(row.startsAt) } ?? true)
            }
            .sorted { ($0.startsAt, $0.id.uuidString) < ($1.startsAt, $1.id.uuidString) }
        let offset = cursor ?? 0
        let slice = rows.dropFirst(offset).prefix(pageSize)
        let next = offset + slice.count < rows.count ? offset + slice.count : nil
        return Page(items: slice.map { makeActivity($0, viewer: me.id, origin: query.origin) }, nextCursor: next)
    }

    func activity(id: UUID) async throws -> Activity {
        let me = try requireUser()
        return makeActivity(try visibleActivity(id, for: me.id), viewer: me.id)
    }

    func privateDetails(activityID: UUID) async throws -> ActivityPrivateDetails? {
        let me = try requireUser()
        let row = try visibleActivity(activityID, for: me.id)
        guard isParticipant(row, me.id) else { return nil }
        return ActivityPrivateDetails(venueName: row.venueName, address: row.address,
                                      coordinate: row.exactCoordinate, meetingNotes: row.meetingNotes)
    }

    func createActivity(_ draft: ActivityDraft) async throws -> Activity {
        let me = try requireActiveUser()
        if let existing = state.activities.values.first(where: { $0.hostID == me.id && $0.clientRequestID == draft.clientRequestID }) {
            return makeActivity(existing, viewer: me.id) // idempotent retry
        }
        switch TrustPolicyEvaluator(policy: .launch).hostingEligibility(for: makeMyProfile(me), now: now) {
        case .eligible: break
        case .needsVerification: throw AppError.rule(.verificationRequired)
        case .hostingRestricted: throw AppError.rule(.hostingRestricted)
        case .suspended: throw AppError.rule(.accountSuspended)
        case .onboardingIncomplete: throw AppError.rule(.onboardingIncomplete)
        }
        try validate(draft, approvedCount: 0, isEditing: false)
        try checkRate("create_activity", userID: me.id, limit: 5, window: 86_400)

        let coordinate = draft.meetingCoordinate!
        let row = MockState.ActivityRow(
            id: UUID(), hostID: me.id, title: draft.title.trimmed, description: draft.description.trimmed,
            category: draft.category!, startsAt: draft.startsAt, endsAt: draft.hasEndTime ? draft.endsAt : nil,
            timeZoneID: ActivityTime.defaultTimeZoneID, capacity: draft.capacity, neighborhoodID: draft.neighborhoodID!,
            approxCoordinate: LocationPrivacy.approximate(coordinate), status: .published, joinPolicy: draft.joinPolicy,
            skillLevel: draft.skillLevel, equipment: draft.equipment.nilIfBlank, instructions: draft.instructions.nilIfBlank,
            coverImageURL: try storeCover(draft.coverImageData), createdAt: now, updatedAt: now,
            clientRequestID: draft.clientRequestID, venueName: draft.venueName.trimmed, address: draft.address.trimmed,
            exactCoordinate: coordinate, meetingNotes: draft.meetingNotes.nilIfBlank)
        state.activities[row.id] = row
        persist()
        let id = row.id
        scheduleSimulation({ backend in backend.simulateJoinRequests(activityID: id) }, after: options.simulationDelay * 2)
        return makeActivity(row, viewer: me.id)
    }

    func updateActivity(id: UUID, draft: ActivityDraft) async throws -> Activity {
        let me = try requireActiveUser()
        guard var row = state.activities[id] else { throw AppError.notFound }
        guard row.hostID == me.id else { throw AppError.rule(.notHost) }
        guard row.status == .published else { throw AppError.rule(.activityNotOpen) }
        guard row.startsAt > now else { throw AppError.rule(.activityStarted) }
        let approved = approvedCount(id)
        if draft.capacity < approved { throw AppError.rule(.capacityBelowApproved) }
        try validate(draft, approvedCount: approved, isEditing: true)
        let coordinate = draft.meetingCoordinate!
        row.title = draft.title.trimmed
        row.description = draft.description.trimmed
        row.category = draft.category!
        row.startsAt = draft.startsAt
        row.endsAt = draft.hasEndTime ? draft.endsAt : nil
        row.capacity = draft.capacity
        row.neighborhoodID = draft.neighborhoodID!
        row.approxCoordinate = LocationPrivacy.approximate(coordinate)
        row.exactCoordinate = coordinate
        row.venueName = draft.venueName.trimmed
        row.address = draft.address.trimmed
        row.meetingNotes = draft.meetingNotes.nilIfBlank
        row.skillLevel = draft.skillLevel
        row.equipment = draft.equipment.nilIfBlank
        row.instructions = draft.instructions.nilIfBlank
        row.joinPolicy = draft.joinPolicy
        if let cover = try storeCover(draft.coverImageData) { row.coverImageURL = cover }
        row.updatedAt = now
        state.activities[id] = row
        persist()
        return makeActivity(row, viewer: me.id)
    }

    func cancelActivity(id: UUID, reason: String) async throws {
        let me = try requireUser()
        guard var row = state.activities[id] else { throw AppError.notFound }
        guard row.hostID == me.id else { throw AppError.rule(.notHost) }
        guard row.status == .published else { throw AppError.rule(.activityNotOpen) }
        row.status = .cancelled
        row.updatedAt = now
        state.activities[id] = row
        persist()
    }

    func hostedActivities() async throws -> [Activity] {
        let me = try requireUser()
        return state.activities.values.filter { $0.hostID == me.id && $0.status != .removed }
            .sorted { $0.startsAt > $1.startsAt }
            .map { makeActivity($0, viewer: me.id) }
    }

    func joinedActivities() async throws -> [Activity] {
        let me = try requireUser()
        let ids = Set(state.members.filter { $0.userID == me.id && [.pending, .approved, .attended, .noShow].contains($0.state) }.map(\.activityID))
        return ids.compactMap { state.activities[$0] }.filter { $0.status != .removed }
            .sorted { $0.startsAt > $1.startsAt }
            .map { makeActivity($0, viewer: me.id) }
    }

    func activities(hostedBy userID: UUID) async throws -> [Activity] {
        let me = try requireUser()
        guard !isBlocked(me.id, userID) else { return [] }
        return state.activities.values
            .filter { $0.hostID == userID && $0.status == .published && $0.startsAt > now }
            .sorted { $0.startsAt < $1.startsAt }
            .map { makeActivity($0, viewer: me.id) }
    }

    private func validate(_ draft: ActivityDraft, approvedCount: Int, isEditing: Bool) throws(AppError) {
        let issues = ActivityValidator(policy: .launch).issues(for: draft, now: now, approvedCount: approvedCount, isEditing: isEditing)
        guard let first = issues.first else { return }
        switch first {
        case .startTooSoon, .startTooFar, .endBeforeStart, .durationTooLong: throw .rule(.invalidSchedule)
        case .venueNotConfirmedPublic: throw .rule(.publicVenueRequired)
        case .outsideServiceArea: throw .rule(.outsideServiceArea)
        case .capacityOutOfRange where approvedCount > draft.capacity: throw .rule(.capacityBelowApproved)
        default: throw .rule(.invalidInput)
        }
    }

    private func storeCover(_ data: Data?) throws -> URL? {
        guard let data else { return nil }
        guard data.count <= 5 * 1024 * 1024 else { throw AppError.rule(.invalidInput) }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mock-covers", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - MembershipRepository

extension MockBackend: MembershipRepository {
    func requestToJoin(activityID: UUID, note: String?) async throws -> MembershipState {
        let me = try requireActiveUser()
        let row = try visibleActivity(activityID, for: me.id)
        guard row.hostID != me.id else { throw AppError.rule(.invalidTransition) }
        guard row.status == .published, row.startsAt > now else { throw AppError.rule(.activityNotOpen) }

        let current = memberIndex(activityID, me.id).map { state.members[$0].state }
        switch current {
        case .pending?, .approved?, .attended?: return current! // idempotent
        case .rejected?, .removed?, .noShow?: throw AppError.rule(.requestClosed)
        case .cancelled?, nil: break
        }
        if hasBlockConflict(activity: row, userID: me.id) { throw AppError.rule(.unavailable) }
        try checkRate("join_request", userID: me.id, limit: 20, window: 3600)

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280).description.nilIfBlank
        if row.joinPolicy == .open {
            if approvedCount(activityID) >= row.capacity { throw AppError.rule(.activityFull) }
            try transition(activityID, me.id, to: .approved, actor: .system, note: trimmedNote)
        } else {
            if approvedCount(activityID) >= row.capacity { throw AppError.rule(.activityFull) }
            try transition(activityID, me.id, to: .pending, actor: .member, note: trimmedNote)
            let userID = me.id
            scheduleSimulation { backend in backend.simulateHostDecision(activityID: activityID, userID: userID) }
        }
        persist()
        return memberIndex(activityID, me.id).map { state.members[$0].state } ?? .pending
    }

    func cancelMembership(activityID: UUID) async throws {
        let me = try requireUser()
        try transition(activityID, me.id, to: .cancelled, actor: .member)
        persist()
    }

    func members(activityID: UUID) async throws -> [Member] {
        let me = try requireUser()
        let row = try visibleActivity(activityID, for: me.id)
        let isHost = row.hostID == me.id
        guard isHost || isParticipant(row, me.id) else { throw AppError.rule(.notParticipant) }
        return state.members
            .filter { $0.activityID == activityID && (isHost || $0.state.occupiesSpot) }
            .filter { isHost || !isBlocked($0.userID, me.id) }
            .sorted { $0.requestedAt < $1.requestedAt }
            .map { Member(user: summary($0.userID), state: $0.state, note: isHost ? $0.note : nil, requestedAt: $0.requestedAt) }
    }

    private func requireHostedActivity(_ activityID: UUID) throws(AppError) -> MockState.ActivityRow {
        let me = try requireUser()
        guard let row = state.activities[activityID] else { throw .notFound }
        guard row.hostID == me.id else { throw .rule(.notHost) }
        return row
    }

    func approve(activityID: UUID, userID: UUID) async throws {
        let row = try requireHostedActivity(activityID)
        guard row.status == .published else { throw AppError.rule(.activityNotOpen) }
        if hasBlockConflict(activity: row, userID: userID) { throw AppError.rule(.unavailable) }
        // The actor serialises approvals, which plays the role of the row lock taken in SQL.
        try transition(activityID, userID, to: .approved, actor: .host)
        persist()
    }

    func reject(activityID: UUID, userID: UUID) async throws {
        _ = try requireHostedActivity(activityID)
        try transition(activityID, userID, to: .rejected, actor: .host)
        persist()
    }

    func remove(activityID: UUID, userID: UUID) async throws {
        _ = try requireHostedActivity(activityID)
        try transition(activityID, userID, to: .removed, actor: .host)
        persist()
    }

    func markAttendance(activityID: UUID, userID: UUID, attended: Bool) async throws {
        let row = try requireHostedActivity(activityID)
        guard row.startsAt <= now else { throw AppError.rule(.invalidTransition) }
        try transition(activityID, userID, to: attended ? .attended : .noShow, actor: .host)
        persist()
    }
}

// MARK: - ChatRepository

extension MockBackend: ChatRepository {
    func threads() async throws -> [ChatThread] {
        let me = try requireUser()
        return state.activities.values
            .filter { $0.status != .removed && isParticipant($0, me.id) }
            .map { row in
                let visible = state.messages.filter { $0.activityID == row.id && !isBlocked($0.senderID ?? me.id, me.id) }
                let last = visible.max { $0.createdAt < $1.createdAt }
                let lastRead = state.readState["\(row.id)|\(me.id)"] ?? .distantPast
                let unread = visible.filter { $0.createdAt > lastRead && $0.senderID != me.id }.count
                return ChatThread(activityID: row.id, title: row.title, category: row.category, startsAt: row.startsAt,
                                  timeZoneID: row.timeZoneID, isHost: row.hostID == me.id,
                                  lastMessagePreview: last?.body, lastMessageAt: last?.createdAt,
                                  unreadCount: unread, status: row.status)
            }
            .sorted { ($0.lastMessageAt ?? $0.startsAt) > ($1.lastMessageAt ?? $1.startsAt) }
    }

    func messages(activityID: UUID, before: Date?, limit: Int) async throws -> [ChatMessage] {
        let me = try requireUser()
        let row = try visibleActivity(activityID, for: me.id)
        guard isParticipant(row, me.id) else { throw AppError.rule(.notParticipant) }
        return state.messages
            .filter { row in row.activityID == activityID && (before.map { row.createdAt < $0 } ?? true) }
            .filter { !isBlocked($0.senderID ?? me.id, me.id) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .reversed()
            .map(makeMessage)
    }

    func send(activityID: UUID, body: String, clientMessageID: UUID) async throws -> ChatMessage {
        let me = try requireUser()
        if me.restrictions.isSuspended(at: now) { throw AppError.rule(.accountSuspended) }
        let row = try visibleActivity(activityID, for: me.id)
        guard isParticipant(row, me.id), row.status == .published || row.status == .completed else {
            throw AppError.rule(.notParticipant)
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...2000).contains(trimmed.count) else { throw AppError.rule(.invalidInput) }
        if let existing = state.messages.first(where: { $0.senderID == me.id && $0.clientMessageID == clientMessageID }) {
            return makeMessage(existing)
        }
        try checkRate("message", userID: me.id, limit: 30, window: 60)
        let message = MockState.MessageRow(id: UUID(), activityID: activityID, senderID: me.id, body: trimmed,
                                           createdAt: now, clientMessageID: clientMessageID)
        state.messages.append(message)
        state.readState["\(activityID)|\(me.id)"] = now
        persist()
        broadcast(message)
        let userID = me.id
        scheduleSimulation({ backend in backend.simulateReply(activityID: activityID, excluding: userID) },
                           after: options.simulationDelay + .seconds(1))
        return makeMessage(message)
    }

    func markRead(activityID: UUID) async throws {
        let me = try requireUser()
        state.readState["\(activityID)|\(me.id)"] = now
        persist()
    }

    nonisolated func liveMessages(activityID: UUID) -> AsyncStream<ChatMessage> {
        let (stream, continuation) = AsyncStream<ChatMessage>.makeStream()
        let token = UUID()
        Task { await self.addContinuation(continuation, activityID: activityID, token: token) }
        continuation.onTermination = { _ in
            Task { await self.removeContinuation(activityID: activityID, token: token) }
        }
        return stream
    }
}

// MARK: - SafetyRepository

extension MockBackend: SafetyRepository {
    /// Mirrors `public.block_user`: blocking removes the blocked person from your hosted
    /// activities and withdraws you from activities they host.
    func block(userID: UUID) async throws {
        let me = try requireUser()
        guard userID != me.id else { throw AppError.rule(.cannotBlockSelf) }
        guard !state.blocks.contains(where: { $0.blockerID == me.id && $0.blockedID == userID }) else { return }
        state.blocks.append(.init(blockerID: me.id, blockedID: userID, createdAt: now))
        for index in state.members.indices {
            let member = state.members[index]
            guard let row = state.activities[member.activityID], row.startsAt > now else { continue }
            if row.hostID == me.id && member.userID == userID {
                if member.state == .pending { state.members[index].state = .rejected }
                if member.state == .approved { state.members[index].state = .removed }
            } else if row.hostID == userID && member.userID == me.id && [.pending, .approved].contains(member.state) {
                state.members[index].state = .cancelled
            }
        }
        persist()
    }

    func unblock(userID: UUID) async throws {
        let me = try requireUser()
        state.blocks.removeAll { $0.blockerID == me.id && $0.blockedID == userID }
        persist()
    }

    func blockedUsers() async throws -> [BlockedUser] {
        let me = try requireUser()
        return state.blocks.filter { $0.blockerID == me.id }
            .sorted { $0.createdAt > $1.createdAt }
            .map { BlockedUser(user: summary($0.blockedID), blockedAt: $0.createdAt) }
    }

    func submitReport(_ draft: ReportDraft) async throws {
        let me = try requireUser()
        guard draft.reportedUserID != me.id else { throw AppError.rule(.cannotReportSelf) }
        guard let category = draft.category, draft.description.count <= ReportDraft.maxDescriptionLength else {
            throw AppError.rule(.invalidInput)
        }
        if state.reports.contains(where: { $0.reporterID == me.id && $0.clientRequestID == draft.clientRequestID }) { return }
        try checkRate("report", userID: me.id, limit: 10, window: 86_400)
        state.reports.append(.init(id: UUID(), reporterID: me.id, reportedUserID: draft.reportedUserID,
                                   activityID: draft.activityID, messageID: draft.messageID, category: category,
                                   description: draft.description.trimmed, status: .open, createdAt: now,
                                   clientRequestID: draft.clientRequestID))
        persist()
    }

    func myReports() async throws -> [ReportRecord] {
        let me = try requireUser()
        return state.reports.filter { $0.reporterID == me.id }
            .sorted { $0.createdAt > $1.createdAt }
            .map { ReportRecord(id: $0.id, category: $0.category, status: $0.status, createdAt: $0.createdAt,
                                reportedUserName: $0.reportedUserID.flatMap { state.users[$0]?.displayName }) }
    }

    func submitFeedback(_ draft: FeedbackDraft) async throws {
        let me = try requireUser()
        guard let row = state.activities[draft.activityID] else { throw AppError.notFound }
        let participated = row.hostID != me.id
            && memberIndex(row.id, me.id).map { [.approved, .attended].contains(state.members[$0].state) } == true
        guard participated, row.startsAt <= now else { throw AppError.rule(.feedbackNotAllowed) }
        guard (1...5).contains(draft.rating), draft.comment.count <= 1000 else { throw AppError.rule(.invalidInput) }
        state.feedback.removeAll { $0.activityID == draft.activityID && $0.reviewerID == me.id }
        state.feedback.append(.init(activityID: draft.activityID, reviewerID: me.id, rating: draft.rating,
                                    feltSafe: draft.feltSafe, comment: draft.comment.trimmed, createdAt: now))
        persist()
    }

    func hasSubmittedFeedback(activityID: UUID) async throws -> Bool {
        let me = try requireUser()
        return state.feedback.contains { $0.activityID == activityID && $0.reviewerID == me.id }
    }
}

// MARK: - VerificationRepository

extension MockBackend: VerificationRepository {
    func currentState() async throws -> VerificationState {
        try requireUser().verification
    }

    func startVerification() async throws -> VerificationStart {
        var user = try requireActiveUser()
        try checkRate("verification", userID: user.id, limit: 3, window: 86_400)
        user.verification = VerificationState(status: .pending, provider: "mock")
        state.users[user.id] = user
        pendingVerification = true
        persist()
        return VerificationStart(url: nil, isMockProvider: true)
    }

    func completeMockVerification(approve: Bool) async throws -> VerificationState {
        var user = try requireUser()
        guard user.verification.status == .pending else { throw AppError.rule(.invalidTransition) }
        user.verification = approve
            ? VerificationState(status: .verified, verifiedAt: now, expiresAt: now.addingTimeInterval(365 * 86_400), provider: "mock")
            : VerificationState(status: .failed, provider: "mock")
        state.users[user.id] = user
        pendingVerification = false
        persist()
        return user.verification
    }
}

// MARK: - NotificationRepository

extension MockBackend: NotificationRepository {
    func registerDeviceToken(_ token: String, environment: String) async throws {
        let me = try requireUser()
        state.deviceTokens[token] = me.id
        persist()
    }

    func unregisterDeviceToken(_ token: String) async throws {
        state.deviceTokens[token] = nil
        persist()
    }

    func preferences() async throws -> NotificationPreferences {
        let me = try requireUser()
        return state.preferences[me.id] ?? NotificationPreferences()
    }

    func updatePreferences(_ preferences: NotificationPreferences) async throws {
        let me = try requireUser()
        state.preferences[me.id] = preferences
        persist()
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}
