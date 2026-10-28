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
                    .frame(height: 140)
                HStack(alignment: .top) {
                    CategoryTag(category: activity.category)
                    Spacer()
                    spotsTag
                }
                .padding(Theme.Spacing.m)
            }
            Rectangle().fill(Theme.Palette.ink).frame(height: Theme.Stroke.hairline)

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(ActivityTime.smartString(activity.startsAt, timeZoneID: activity.timeZoneID))
                    .rvLabelStyle()
                    .foregroundStyle(Theme.Palette.accentText)
                Text(activity.title)
                    .font(.rvHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(locationLine)
                    .rvLabelStyle(.rvCaption)
                    .foregroundStyle(Theme.Palette.inkSecondary)

                Rectangle().fill(Theme.Palette.hairline).frame(height: 1)

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
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.regular))
        .echoShadow(Theme.Palette.ink)
        .accessibilityElement(children: .contain)
    }

    private var locationLine: String {
        let name = activity.neighborhood?.name ?? ""
        guard let distance = activity.distanceMeters else { return name }
        return "\(name) · \(LocationPrivacy.distanceString(distance))"
    }

    @ViewBuilder private var spotsTag: some View {
        if activity.isFull {
            StatusPill(text: String(localized: "activity.full"), inverted: true)
        } else {
            StatusPill(text: String(localized: "activity.spots_left \(activity.spotsLeft)"), background: Theme.Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.hairline))
        }
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
            StatusPill(text: state.title, symbol: state.symbol, inverted: state == .going)
        }
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.frame(width: 18).foregroundStyle(Theme.Palette.ink)
            configuration.title.lineLimit(1)
        }
    }
}

struct ActivityCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.Palette.surfaceMuted).frame(height: 140)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(verbatim: "Placeholder activity title here").font(.rvHeadline)
                Text(verbatim: "Saturday, 17:00").font(.subheadline)
                Text(verbatim: "Neighbourhood · 1 km").font(.subheadline)
                HStack { Circle().frame(width: 28, height: 28); Text(verbatim: "Host name"); Spacer() }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Stroke.regular))
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
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.hairline))
            VStack(alignment: .leading, spacing: 3) {
                Text(ActivityTime.smartString(activity.startsAt, timeZoneID: activity.timeZoneID))
                    .rvLabelStyle(.rvCaption).foregroundStyle(Theme.Palette.accentText)
                Text(activity.title).font(.system(.body, design: .serif).weight(.medium)).foregroundStyle(Theme.Palette.ink).lineLimit(2)
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
                .foregroundStyle(state.occupiesSpot ? Theme.Palette.ink : Theme.Palette.inkSecondary)
        } else {
            Text("activity.approved_count \(activity.approvedCount) \(activity.capacity)")
                .rvLabelStyle(.rvCaption).foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
}
