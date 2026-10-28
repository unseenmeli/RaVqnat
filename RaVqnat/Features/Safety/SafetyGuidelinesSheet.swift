import SwiftUI

/// Shown before a user's first join request.
struct SafetyGuidelinesSheet: View {
    let onAccept: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Theme.Palette.trust)
                        .frame(width: 72, height: 72)
                        .background(Theme.Palette.trustSoft, in: Circle())
                        .accessibilityHidden(true)
                    Text("safety.guidelines.title").font(.rvTitle).accessibilityAddTraits(.isHeader)
                    Text("safety.guidelines.intro").foregroundStyle(Theme.Palette.inkSecondary)
                    SafetyTipList()
                    Text("safety.guidelines.disclaimer").font(.footnote).foregroundStyle(Theme.Palette.inkTertiary)
                }
                .padding(Theme.Spacing.screen)
            }
            .safeAreaInset(edge: .bottom) {
                Button("safety.guidelines.accept") { onAccept() }
                    .buttonStyle(.primary)
                    .padding(Theme.Spacing.screen)
                    .background(.bar)
                    .accessibilityIdentifier("safety.accept")
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } } }
        }
    }
}

struct SafetyTipList: View {
    private let tips: [(String, LocalizedStringKey)] = [
        ("building.2.fill", "safety.tip.public"),
        ("person.2.wave.2.fill", "safety.tip.tell_friend"),
        ("car.fill", "safety.tip.own_transport"),
        ("hand.thumbsdown.fill", "safety.tip.leave"),
        ("exclamationmark.bubble.fill", "safety.tip.report"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: tip.0).foregroundStyle(Theme.Palette.trust).frame(width: 24)
                        .accessibilityHidden(true)
                    Text(tip.1).foregroundStyle(Theme.Palette.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .rvCard()
    }
}

struct EmergencyInfoView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("emergency.title").font(.rvTitle).accessibilityAddTraits(.isHeader)
                    Text("emergency.subtitle").foregroundStyle(Theme.Palette.inkSecondary)
                }
                Button {
                    if let url = URL(string: "tel://112") { openURL(url) }
                } label: {
                    Label("emergency.call_112", systemImage: "phone.fill")
                }
                .buttonStyle(.destructive)
                .accessibilityHint(Text("emergency.call_112.hint"))

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Label("emergency.step.safe_place", systemImage: "figure.walk.departure")
                    Label("emergency.step.contact", systemImage: "person.fill.questionmark")
                    Label("emergency.step.report", systemImage: "flag.fill")
                }
                .foregroundStyle(Theme.Palette.ink)
                .rvCard()

                Text("emergency.disclaimer").font(.footnote).foregroundStyle(Theme.Palette.inkTertiary)
            }
            .padding(Theme.Spacing.screen)
        }
        .screenBackground()
        .navigationTitle(Text("emergency.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SafetyCenterView: View {
    var body: some View {
        List {
            Section {
                NavigationLink { EmergencyInfoView() } label: { Label("safety.center.emergency", systemImage: "cross.case.fill") }
                NavigationLink {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                            Text("safety.guidelines.intro").foregroundStyle(Theme.Palette.inkSecondary)
                            SafetyTipList()
                            Text("safety.guidelines.disclaimer").font(.footnote).foregroundStyle(Theme.Palette.inkTertiary)
                        }.padding(Theme.Spacing.screen)
                    }
                    .screenBackground()
                    .navigationTitle(Text("safety.guidelines.title"))
                } label: { Label("safety.center.guidelines", systemImage: "hand.raised.fill") }
            }
            Section {
                NavigationLink { BlockedUsersView() } label: { Label("safety.center.blocked", systemImage: "person.crop.circle.badge.xmark") }
                NavigationLink { ReportHistoryView() } label: { Label("safety.center.reports", systemImage: "flag") }
            } footer: {
                Text("safety.center.footer")
            }
        }
        .navigationTitle(Text("safety.center.title"))
    }
}
