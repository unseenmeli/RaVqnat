import SwiftUI

struct AvatarView: View {
    let name: String
    let url: URL?
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Theme.Palette.surfaceMuted)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .regular, design: .serif))
                .foregroundStyle(Theme.Palette.ink)
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
        .overlay(Circle().strokeBorder(Theme.Palette.ink, lineWidth: size > 60 ? Theme.Stroke.bold : Theme.Stroke.hairline))
        .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "·" : letters.uppercased()
    }
}

struct VerifiedBadge: View {
    var size: Font = .footnote

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(size)
            .foregroundStyle(Theme.Palette.canvas, Theme.Palette.ink)
            .symbolRenderingMode(.palette)
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
