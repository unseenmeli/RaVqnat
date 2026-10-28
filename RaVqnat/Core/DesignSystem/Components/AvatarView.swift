import SwiftUI

struct AvatarView: View {
    let name: String
    let url: URL?
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(fallbackColor.opacity(0.18))
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(fallbackColor)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "·" : letters.uppercased()
    }

    private var fallbackColor: Color {
        let palette = ActivityCategory.allCases.map(\.tint)
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
    }
}

struct VerifiedBadge: View {
    var size: Font = .footnote

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(size)
            .foregroundStyle(Theme.Palette.trust)
            .accessibilityLabel(Text("verification.badge.accessibility"))
    }
}

struct UserRow: View {
    let user: UserSummary
    var subtitle: String?
    var avatarSize: CGFloat = 40

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            AvatarView(name: user.displayName, url: user.avatarURL, size: avatarSize)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.displayName).font(.body.weight(.semibold)).foregroundStyle(Theme.Palette.ink)
                    if user.isVerified { VerifiedBadge() }
                }
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
