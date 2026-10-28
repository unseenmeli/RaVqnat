import SwiftUI

/// What the join call-to-action should show for a given activity and viewer.
enum JoinButtonState: Equatable {
    case hosting, requestable(open: Bool), requested, going, full, closed, ended

    init(activity: Activity, viewerID: UUID?, now: Date = .now) {
        if activity.isHost(viewerID) { self = .hosting; return }
        if activity.status != .published || activity.hasStarted(at: now) {
            self = activity.myMembership?.occupiesSpot == true ? .going : .ended
            return
        }
        switch activity.myMembership {
        case .pending?: self = .requested
        case .approved?, .attended?: self = .going
        case .rejected?, .removed?, .noShow?: self = .closed
        case .cancelled?, nil: self = activity.isFull ? .full : .requestable(open: activity.joinPolicy == .open)
        }
    }

    var title: String {
        switch self {
        case .hosting: String(localized: "join.hosting")
        case .requestable(let open): open ? String(localized: "join.join") : String(localized: "join.request")
        case .requested: String(localized: "join.requested")
        case .going: String(localized: "join.going")
        case .full: String(localized: "join.full")
        case .closed: String(localized: "join.unavailable")
        case .ended: String(localized: "join.ended")
        }
    }

    var symbol: String? {
        switch self {
        case .requested: "clock"
        case .going: "checkmark"
        case .hosting: "star.fill"
        default: nil
        }
    }

    var isActionable: Bool { if case .requestable = self { true } else { false } }
}

struct ActivityCard: View {
    let activity: Activity
    let viewerID: UUID?
    var isJoining = false
    var onJoin: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            // Full-bleed post: generously rounded top, straight bottom edge.
            ActivityCoverArt(category: activity.category, seed: activity.id, imageURL: activity.coverImageURL)
                .frame(height: 260)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.post, topTrailingRadius: Theme.Radius.post,
                                                  style: .continuous))
                .overlay(alignment: .topLeading) {
                    HStack {
                        CategoryTag(category: activity.category)
                        Spacer()
                        StatusPill(text: activity.isFull ? String(localized: "activity.full") : String(localized: "activity.spots_left \(activity.spotsLeft)"),
                                   background: .clear)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .padding(Theme.Spacing.l)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ActivityTime.smartString(activity.startsAt, timeZoneID: activity.timeZoneID))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer()
                    if let distance = activity.distanceMeters {
                        Text(LocationPrivacy.distanceString(distance))
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }
                Text(activity.title)
                    .font(.title3.weight(.semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(activity.neighborhood?.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .padding(.horizontal, Theme.Spacing.screen)

            HStack(spacing: Theme.Spacing.s) {
                AvatarView(name: activity.host.displayName, url: activity.host.avatarURL, size: 28)
                Text(activity.host.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(1)
                if activity.host.isVerified { VerifiedBadge(size: .caption) }
                Spacer(minLength: Theme.Spacing.s)
                joinButton
            }
            .padding(.horizontal, Theme.Spacing.screen)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var joinButton: some View {
        let state = JoinButtonState(activity: activity, viewerID: viewerID)
        if state.isActionable, let onJoin {
            Button(action: onJoin) {
                if isJoining { ProgressView().tint(Theme.Palette.canvas) } else { Text(state.title) }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(isJoining)
            .accessibilityIdentifier("card.join.\(activity.id.uuidString)")
            .accessibilityHint(Text("join.hint \(activity.title)"))
        } else {
            StatusPill(text: state.title, symbol: state.symbol,
                       tint: state == .going ? Theme.Palette.success : Theme.Palette.inkSecondary)
        }
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.frame(width: 18).foregroundStyle(Theme.Palette.inkTertiary)
            configuration.title.lineLimit(1)
        }
    }
}

struct ActivityCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.post, topTrailingRadius: Theme.Radius.post, style: .continuous)
                .fill(Theme.Palette.surfaceMuted).frame(height: 260)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Saturday, 17:00").font(.subheadline)
                Text(verbatim: "Placeholder activity title here").font(.title3)
                Text(verbatim: "Neighbourhood").font(.subheadline)
            }
            .padding(.horizontal, Theme.Spacing.screen)
        }
        .skeleton()
    }
}

/// Compact row used in lists (profile, map list mode).
struct ActivityRow: View {
    let activity: Activity
    var showStatus = true

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ActivityCoverArt(category: activity.category, seed: activity.id, imageURL: activity.coverImageURL)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title).font(.body.weight(.semibold)).foregroundStyle(Theme.Palette.ink).lineLimit(2)
                Text(ActivityTime.smartString(activity.startsAt, timeZoneID: activity.timeZoneID))
                    .font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
                if showStatus { statusLine }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.Palette.inkTertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var statusLine: some View {
        if activity.status == .cancelled {
            Text("activity.status.cancelled").rvLabelStyle(.rvCaption).foregroundStyle(Theme.Palette.danger)
        } else if let state = activity.myMembership {
            Text(state.title).rvLabelStyle(.rvCaption)
                .foregroundStyle(state.occupiesSpot ? Theme.Palette.success : Theme.Palette.inkSecondary)
        } else {
            Text("activity.approved_count \(activity.approvedCount) \(activity.capacity)")
                .rvLabelStyle(.rvCaption).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
}
