import AuthenticationServices
import CryptoKit
import Foundation
import Observation

/// Authentication and profile state for the whole app.
@MainActor
@Observable
final class AppSession {
    enum Phase: Equatable {
        case launching
        case signedOut
        case onboarding
        case ready
    }

    private(set) var phase: Phase = .launching
    private(set) var profile: MyProfile?
    private(set) var trustPolicy: TrustPolicy = .launch
    private(set) var isWorking = false
    var error: AppError?

    private let env: AppEnvironment
    private var currentNonce: String?

    init(env: AppEnvironment) { self.env = env }

    var userID: UUID? { profile?.id }
    var hostingEligibility: HostingEligibility {
        guard let profile else { return .onboardingIncomplete }
        return TrustPolicyEvaluator(policy: trustPolicy).hostingEligibility(for: profile)
    }

    func bootstrap() async {
        if env.config.isUITesting, ProcessInfo.processInfo.arguments.contains(LaunchArgument.signedIn),
           let backend = env.auth as? MockBackend {
            await backend.upsertUser(MockSeed.demoUser(onboarded: true))
            await backend.setCurrentUser(MockSeed.demoUserID)
        }
        guard await env.auth.restoreSession() != nil else {
            phase = .signedOut
            return
        }
        await loadProfile()
    }

    private func loadProfile() async {
        do {
            async let policy = env.profiles.trustPolicy()
            let profile = try await env.profiles.myProfile()
            self.trustPolicy = (try? await policy) ?? .launch
            apply(profile)
        } catch AppError.unauthorized {
            phase = .signedOut
        } catch {
            // Keep the user signed in; screens show their own error states and can retry.
            self.error = AppError.from(error)
            if profile == nil { phase = .signedOut }
        }
    }

    private func apply(_ profile: MyProfile) {
        self.profile = profile
        phase = profile.onboardingCompleted ? .ready : .onboarding
        if phase == .ready { Task { await env.push.registerIfAuthorized() } }
    }

    // MARK: Sign in with Apple

    /// Configures the Apple request with a SHA-256 hashed nonce (the raw nonce goes to Supabase).
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [] // We do not need the user's name or email from Apple.
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, any Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            Log.auth.error("Apple sign-in failed")
            self.error = .signInFailed
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                self.error = .signInFailed
                return
            }
            await perform { try await self.env.auth.signInWithApple(identityToken: token, rawNonce: nonce) }
        }
    }

    func signInAsDemoUser() async {
        await perform { try await self.env.auth.signInAsDemoUser() }
    }

    private func perform(_ signIn: @escaping () async throws -> AuthSession) async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await signIn()
            await loadProfile()
        } catch {
            self.error = AppError.from(error) == .unknown ? .signInFailed : AppError.from(error)
        }
    }

    // MARK: Profile lifecycle

    func didCompleteOnboarding(_ profile: MyProfile) {
        apply(profile)
    }

    func update(_ profile: MyProfile) {
        self.profile = profile
    }

    func refreshProfile() async {
        guard phase == .ready || phase == .onboarding else { return }
        if let profile = try? await env.profiles.myProfile() { self.profile = profile }
        if let policy = try? await env.profiles.trustPolicy() { trustPolicy = policy }
    }

    func signOut() async {
        await env.push.unregister()
        try? await env.auth.signOut()
        await env.reminders.cancelAll()
        profile = nil
        phase = .signedOut
    }

    func deleteAccount() async throws {
        await env.push.unregister()
        try await env.auth.deleteAccount()
        await env.reminders.cancelAll()
        profile = nil
        phase = .signedOut
    }

    // MARK: Nonce helpers

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count, using: &generator)] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
