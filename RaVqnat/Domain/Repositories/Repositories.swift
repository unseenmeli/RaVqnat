import Foundation

struct AuthSession: Sendable, Equatable {
    let userID: UUID
}

protocol AuthRepository: Sendable {
    /// Restores a persisted session (Keychain-backed for Supabase).
    func restoreSession() async -> AuthSession?
    /// Exchanges an Apple identity token (with the raw nonce used to request it) for a session.
    func signInWithApple(identityToken: String, rawNonce: String) async throws -> AuthSession
    func signOut() async throws
    /// Permanently deletes the account server-side, then clears the local session.
    func deleteAccount() async throws
    /// Demo sign-in, only supported by the mock backend.
    var supportsDemoSignIn: Bool { get }
    func signInAsDemoUser() async throws -> AuthSession
}

protocol ProfileRepository: Sendable {
    func myProfile() async throws -> MyProfile
    func completeOnboarding(_ submission: OnboardingSubmission) async throws -> MyProfile
    func updateProfile(_ update: ProfileUpdate) async throws -> MyProfile
    func uploadAvatar(jpegData: Data) async throws -> MyProfile
    func profile(id: UUID) async throws -> PublicProfile
    func trustPolicy() async throws -> TrustPolicy
}

protocol ActivityRepository: Sendable {
    func nearbyActivities(_ query: ActivityQuery, cursor: Int?, pageSize: Int) async throws -> Page<Activity>
    func activity(id: UUID) async throws -> Activity
    /// Returns nil when the viewer is not allowed to see exact meeting details.
    func privateDetails(activityID: UUID) async throws -> ActivityPrivateDetails?
    func createActivity(_ draft: ActivityDraft) async throws -> Activity
    func updateActivity(id: UUID, draft: ActivityDraft) async throws -> Activity
    func cancelActivity(id: UUID, reason: String) async throws
    func hostedActivities() async throws -> [Activity]
    func joinedActivities() async throws -> [Activity]
    func activities(hostedBy userID: UUID) async throws -> [Activity]
}

protocol MembershipRepository: Sendable {
    func requestToJoin(activityID: UUID, note: String?) async throws -> MembershipState
    func cancelMembership(activityID: UUID) async throws
    func members(activityID: UUID) async throws -> [Member]
    func approve(activityID: UUID, userID: UUID) async throws
    func reject(activityID: UUID, userID: UUID) async throws
    func remove(activityID: UUID, userID: UUID) async throws
    func markAttendance(activityID: UUID, userID: UUID, attended: Bool) async throws
}

protocol ChatRepository: Sendable {
    func threads() async throws -> [ChatThread]
    /// Messages newest-last; pass the oldest loaded date to page backwards.
    func messages(activityID: UUID, before: Date?, limit: Int) async throws -> [ChatMessage]
    func send(activityID: UUID, body: String, clientMessageID: UUID) async throws -> ChatMessage
    func markRead(activityID: UUID) async throws
    /// Live stream of new messages for one activity. Ends when the consumer's task is cancelled.
    func liveMessages(activityID: UUID) -> AsyncStream<ChatMessage>
}

protocol StoryRepository: Sendable {
    /// Live stories (not expired) from activities the viewer can see, unseen groups first.
    func storyFeed() async throws -> [StoryGroup]
    /// Activities the viewer may post a story to (hosting, or approved participant).
    func storyEligibleActivities() async throws -> [Activity]
    func postStory(_ draft: StoryDraft) async throws -> Story
    func markStorySeen(_ storyID: UUID) async throws
    func deleteStory(_ storyID: UUID) async throws
}

protocol SafetyRepository: Sendable {
    func block(userID: UUID) async throws
    func unblock(userID: UUID) async throws
    func blockedUsers() async throws -> [BlockedUser]
    func submitReport(_ draft: ReportDraft) async throws
    func myReports() async throws -> [ReportRecord]
    func submitFeedback(_ draft: FeedbackDraft) async throws
    func hasSubmittedFeedback(activityID: UUID) async throws -> Bool
}

protocol VerificationRepository: Sendable {
    func currentState() async throws -> VerificationState
    func startVerification() async throws -> VerificationStart
    /// Mock provider only: completes the pending verification (server rejects this in production).
    func completeMockVerification(approve: Bool) async throws -> VerificationState
}

protocol InboxRepository: Sendable {
    func inbox() async throws -> [InboxItem]
    func unreadInboxCount() async throws -> Int
    func markAllRead() async throws
}

protocol NotificationRepository: Sendable {
    func registerDeviceToken(_ token: String, environment: String) async throws
    func unregisterDeviceToken(_ token: String) async throws
    func preferences() async throws -> NotificationPreferences
    func updatePreferences(_ preferences: NotificationPreferences) async throws
}
