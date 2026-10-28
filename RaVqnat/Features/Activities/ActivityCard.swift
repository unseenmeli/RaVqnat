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
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ActivityCoverArt(category: activity.category, seed: activity.id, imageURL: activity.coverImageURL)
                    .frame(height: 150)
                HStack {
                    CategoryTag(category: activity.category, onDark: activity.coverImageURL != nil)
                    Spacer()
                    spotsPill
                }
                .padding(Theme.Spacing.m)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(activity.title)
                    .font(.rvHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 4) {
                    Label(ActivityTime.smartString(activity.startsAt, timeZoneID: activity.timeZoneID), systemImage: "calendar")
                    Label(locationLine, systemImage: "mappin.and.ellipse")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .labelStyle(CompactLabelStyle())

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
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.Palette.hairline.opacity(0.6), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
    }

    private var locationLine: String {
        let name = activity.neighborhood?.name ?? ""
        guard let distance = activity.distanceMeters else { return name }
        return "\(name) · \(LocationPrivacy.distanceString(distance))"
    }

    @ViewBuilder private var spotsPill: some View {
        if activity.isFull {
            StatusPill(text: String(localized: "activity.full"), tint: Theme.Palette.inkSecondary, background: Theme.Palette.surface)
        } else {
            StatusPill(text: String(localized: "activity.spots_left \(activity.spotsLeft)"), symbol: "person.2.fill",
                       tint: Theme.Palette.ink, background: Theme.Palette.surface)
        }
    }

    @ViewBuilder private var joinButton: some View {
        let state = JoinButtonState(activity: activity, viewerID: viewerID)
        if state.isActionable, let onJoin {
            Button(action: onJoin) {
                if isJoining { ProgressView().tint(Theme.Palette.onBrand) } else { Text(state.title) }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(isJoining)
            .accessibilityIdentifier("card.join.\(activity.id.uuidString)")
            .accessibilityHint(Text("join.hint \(activity.title)"))
        } else {
            StatusPill(text: state.title, symbol: state.symbol,
                       tint: state == .going ? Theme.Palette.success : Theme.Palette.inkSecondary,
                       background: state == .going ? Theme.Palette.success.opacity(0.12) : Theme.Palette.surfaceMuted)
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
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.Palette.surfaceMuted).frame(height: 150)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(verbatim: "Placeholder activity title here").font(.rvHeadline)
                Text(verbatim: "Saturday, 17:00").font(.subheadline)
                Text(verbatim: "Neighbourhood · 1 km").font(.subheadline)
                HStack { Circle().frame(width: 28, height: 28); Text(verbatim: "Host name"); Spacer() }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
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
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            Text("activity.status.cancelled").font(.caption.weight(.semibold)).foregroundStyle(Theme.Palette.danger)
        } else if let state = activity.myMembership {
            Text(state.title).font(.caption.weight(.semibold))
                .foregroundStyle(state.occupiesSpot ? Theme.Palette.success : Theme.Palette.inkSecondary)
        } else {
            Text("activity.approved_count \(activity.approvedCount) \(activity.capacity)")
                .font(.caption).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
}
