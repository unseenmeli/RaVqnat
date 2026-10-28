# RaVqnat (რავქნათ) — Architecture

RaVqnat is a native iOS app for organising and joining small, real-life activities in Tbilisi.
This document describes how the system is put together and why.

## 1. System overview

```
┌──────────────────────────── iOS app (SwiftUI, Swift 6) ────────────────────────────┐
│  Features (Views + @Observable ViewModels)                                          │
│      │  depend only on                                                              │
│  Domain (Models, Repository protocols, pure Services: state machine, validators,   │
│          trust policy mirror, location privacy)                                     │
│      │  implemented by                                                              │
│  Data ── Supabase repositories (supabase-swift)    ── Mock repositories (MockBackend)│
└──────────────┬──────────────────────────────────────────────────────────────────────┘
               │ HTTPS (anon key + user JWT only)
┌──────────────▼──────────────────── Supabase ─────────────────────────────────────────┐
│ Auth (Sign in with Apple)  PostgREST  Realtime  Storage  Edge Functions (Deno)      │
│ PostgreSQL + PostGIS: RLS on every table, SECURITY DEFINER RPCs for business rules  │
└──────────────┬──────────────────────────────────────────────────────────────────────┘
               │ service role (server only)
        APNs (token auth) · Identity verification provider (pluggable)
```

The app never holds privileged credentials. Every rule that matters for safety or
consistency (capacity, membership transitions, blocking, hosting eligibility, rate
limits, verification state) is enforced in PostgreSQL. The client mirrors some rules
only to give fast, friendly feedback.

## 2. iOS modules

```
RaVqnat/
  App/            entry point, AppEnvironment (DI), session state, routing, tabs, push delegate
  Core/
    Configuration/ AppConfig (reads Info.plist values injected from xcconfig)
    DesignSystem/  colors, typography, spacing, components (cards, chips, skeletons, badges)
    Errors/        AppError — one user-presentable error type
    Utilities/     haptics, date formatting (Asia/Tbilisi), logging (privacy-aware)
  Domain/
    Models/        Activity, Membership, Profile, ChatMessage, Report, … (pure value types)
    Repositories/  protocols consumed by view models
    Services/      MembershipStateMachine, ActivityValidator, OnboardingValidator,
                   TrustPolicy, LocationPrivacy, ReminderScheduler, LocationProvider
  Data/
    Mock/          MockBackend actor + repositories (operational offline/demo mode)
    Supabase/      client provider, DTOs, repository implementations
  Features/        Onboarding, Explore, Activities, Map, Hosting, Chat, Profile, Safety,
                   Notifications
  Resources/       Assets, Localizable.xcstrings (en + ka), InfoPlist.xcstrings
```

**Dependency injection.** `AppEnvironment` owns one instance of each repository and
service and is put in the SwiftUI environment. View models receive the protocols they
need in their initialisers, so tests construct them with mocks directly.

**Mode selection.** If `SUPABASE_URL` / `SUPABASE_ANON_KEY` are present in the build
configuration the app talks to Supabase; otherwise it runs against `MockBackend`, an
in-memory actor seeded with fictional Tbilisi activities that enforces the same rules
(capacity, transitions, blocks) using the shared domain services. UI tests always use
mock mode (`-uitest` launch argument).

**Data flow.** View → ViewModel (`@MainActor @Observable`) → Repository protocol →
Supabase (RPC/PostgREST/Realtime) or MockBackend → Domain model → ViewModel state
(`LoadState<T>`: idle / loading / loaded / failed) → View. DTOs never leave the Data
layer.

**Errors.** Repositories throw `AppError` (`.network`, `.unauthorized`, `.notFound`,
`.rule(RuleViolation)`, `.rateLimited`, `.unknown`). Server rule violations come back as
Postgres exceptions with stable codes (`RV001`…) that map to localized messages; raw
server messages are never shown.

**Concurrency.** Swift 6 language mode with complete checking. Models are `Sendable`
value types, view models are `@MainActor`, the mock backend is an `actor`.

## 3. Database schema (summary)

| Table | Purpose | Client access |
|---|---|---|
| `profiles` | public profile (name, bio, avatar path, language, neighbourhood) | read: authenticated, minus blocked; update: own row, whitelisted columns |
| `interests`, `user_interests` | interest catalogue and selections | read all / manage own |
| `activity_categories`, `neighborhoods` | reference data (bilingual) | read |
| `trust_policies` | key/value hosting & safety policy | read |
| `activities` | public activity data incl. fuzzed `approx_location` | read published, minus blocked hosts; writes via RPC only |
| `activity_private_details` | exact venue, address, coordinates, instructions | host + approved members only |
| `activity_members` | membership state machine | own rows + host; writes via RPC only |
| `activity_messages` | group chat | participants only; writes via RPC only |
| `chat_read_state` | unread tracking | own rows |
| `user_blocks` | blocks | own rows (as blocker); writes via RPC |
| `reports` | safety reports | reporter sees own (without moderator notes); never the reported user |
| `reviews` | private post-activity feedback | insert via RPC; reviewer sees own only |
| `verification_records` | provider results (no documents) | own status only; writes by service role |
| `account_restrictions` | suspensions, hosting restrictions | own row read-only |
| `moderation_actions`, `appeals`, `audit_log`, `app_admins` | moderation | moderators via RPC; users submit/read own appeals |
| `device_tokens`, `notification_preferences` | push | own rows |
| `notification_outbox` | queued push notifications | service role only |
| `rate_limit_events`, `idempotency_keys` | abuse prevention | none (definer functions) |

Membership states: `pending → approved | rejected | cancelled`, `approved → cancelled |
removed | attended | no_show`. Transitions are validated by a trigger as well as by the
RPCs. Approvals lock the activity row (`SELECT … FOR UPDATE`) and check a
denormalised `approved_count` against `capacity`, so concurrent approvals can never
overbook.

Location: `activities.approx_location` (geography, snapped to a ~300 m grid) powers the
feed and the map. Exact coordinates live in `activity_private_details` and are returned
only to the host and approved members. Device location is sent only as a query
parameter for distance sorting and is never stored.

## 4. Authentication

Sign in with Apple (`AuthenticationServices`) produces an identity token with a hashed
nonce; the app exchanges it with Supabase Auth (`signInWithIdToken`). supabase-swift
stores the session in the Keychain. A trigger on `auth.users` creates the `profiles`
row. Onboarding is completed through `complete_onboarding()`, which validates input and
records age attestation (`age_assurance = self_declared`). Stronger age assurance can be
added by raising `trust_policies.min_age_assurance` — the same verification pipeline
that powers host verification can upgrade `age_assurance` to `verified`.

Onboarding progress is kept in memory and in a small local draft (UserDefaults, no
sensitive data) until submission.

## 5. Security boundaries

1. **Client is untrusted.** No table accepts direct client inserts for business objects;
   column grants restrict what users can update on their own profile. Verification
   status, restrictions, admin roles and counters are server-controlled.
2. **Admin privilege** comes only from `app_admins`, which no client can write.
   Moderation RPCs check `is_moderator()` and write `audit_log`.
3. **Edge Functions** use the service role key from Supabase secrets; the verification
   callback authenticates the provider with an HMAC signature and timestamp.
4. **Storage**: `avatars` and `activity-covers` buckets accept only images ≤ 5 MB in the
   uploader's own folder; `verification-private` has no client policies at all.
5. **Blocking** is enforced in RLS (profile/activity/message visibility) and in RPCs
   (join, approve, send message).

See [SECURITY.md](SECURITY.md) for the threat model and retention rules.

## 6. Key decisions

- **Supabase-swift via SPM** is the only third-party dependency.
- **Folder-synchronised Xcode groups** keep the project file small and conflict-free.
- **RPC-first writes**: atomicity, idempotency (`client_request_id`) and rate limits live
  next to the data, not in Edge Functions, which are reserved for work needing secrets
  (APNs, verification provider, account deletion).
- **Push localisation** uses APNs `loc-key`s that resolve against the app's string
  catalog, so the server never needs to know the UI language and lock-screen text never
  contains message bodies unless the user opts in.
- **Safety check-ins are local notifications**: no background location, no automatic
  contact with anyone.
- **Procedural cover art**: activities without a photo get a deterministic, category-tinted
  illustration built from SF Symbols, so the feed looks good without stock photos of real
  people.
