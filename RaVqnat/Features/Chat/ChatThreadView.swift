import SwiftUI

struct ChatThreadView: View {
    let activityID: UUID
    @Environment(AppEnvironment.self) private var env
    @State private var model: ChatThreadViewModel?

    var body: some View {
        Group {
            if let model { ChatThreadContent(model: model) } else { Color.clear }
        }
        .screenBackground()
        .onAppear {
            if model == nil {
                model = ChatThreadViewModel(activityID: activityID, chat: env.chat, activities: env.activities, safety: env.safety)
            }
        }
    }
}

private struct ChatThreadContent: View {
    @Bindable var model: ChatThreadViewModel
    @Environment(AppSession.self) private var session
    @FocusState private var composerFocused: Bool
    @State private var reportTarget: ReportTarget?
    @State private var blocking: UserSummary?

    var body: some View {
        Group {
            switch model.loadState {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ErrorStateView(error: error) { Task { await model.load() } }
            case .loaded:
                messages
            }
        }
        .navigationTitle(Text(model.activity?.title ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.activity(model.activityID)) { Image(systemName: "info.circle") }
                    .accessibilityLabel(Text("chat.activity_info"))
            }
        }
        .task { await model.load() }
        .task { await model.listen() }
        .sheet(item: $reportTarget) { ReportSheet(target: $0) }
        .blockConfirmation(userName: blocking?.displayName, isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } })) {
            if let user = blocking { Task { await model.block(user) } }
        }
        .alert(Text("state.error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: { Text(model.error?.message ?? "") }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if model.hasMoreHistory {
                        ProgressView()
                            .padding()
                            .task { await model.loadOlder() }
                    }
                    if model.items.isEmpty {
                        EmptyStateView(symbol: "hand.wave.fill", title: String(localized: "chat.empty.title"),
                                       message: String(localized: "chat.empty.message"))
                    }
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        if showsDayHeader(at: index) {
                            Text(item.message.createdAt.formatted(.dateTime.weekday(.wide).day().month()))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Palette.inkTertiary)
                                .padding(.vertical, Theme.Spacing.s)
                        }
                        MessageBubble(item: item,
                                      isMine: item.message.sender.id == session.userID,
                                      showsSender: showsSender(at: index),
                                      isHost: item.message.sender.id == model.activity?.host.id)
                            .id(item.id)
                            .contextMenu { menu(for: item) }
                            .onTapGesture { if item.delivery == .failed { Task { await model.retry(item) } } }
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.items.last?.id) { _, id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
            .safeAreaInset(edge: .bottom) { composer }
        }
    }

    @ViewBuilder private func menu(for item: ChatThreadViewModel.Item) -> some View {
        Button { UIPasteboard.general.string = item.message.body } label: { Label("chat.copy", systemImage: "doc.on.doc") }
        if item.message.sender.id != session.userID {
            Button {
                reportTarget = ReportTarget(userID: item.message.sender.id, userName: item.message.sender.displayName,
                                            activityID: model.activityID, messageID: item.message.id)
            } label: { Label("chat.report", systemImage: "flag") }
            Button(role: .destructive) { blocking = item.message.sender } label: {
                Label("chat.block \(item.message.sender.displayName)", systemImage: "hand.raised.slash")
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            if model.activity?.status == .cancelled {
                Text("chat.cancelled").font(.footnote).foregroundStyle(Theme.Palette.inkSecondary).padding()
            } else {
                HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                    TextField(text: $model.draft, axis: .vertical) { Text("chat.placeholder") }
                        .lineLimit(1...5)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 10)
                        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.Palette.ink, lineWidth: Theme.Stroke.hairline))
                        .focused($composerFocused)
                        .accessibilityIdentifier("chat.composer")
                    Button {
                        guard let me = session.profile?.summary else { return }
                        Task { await model.send(as: me) }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.Palette.canvas)
                            .frame(width: 40, height: 40)
                            .background(model.canSend ? Theme.Palette.ink : Theme.Palette.inkTertiary, in: Rectangle())
                            .background(Rectangle().fill(model.canSend ? Theme.Palette.accent : .clear).offset(x: 3, y: 3))
                    }
                    .disabled(!model.canSend)
                    .accessibilityLabel(Text("chat.send"))
                    .accessibilityIdentifier("chat.send")
                    .sensoryFeedback(.impact(weight: .light), trigger: model.items.count)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
            }
        }
        .background(.bar)
    }

    private func showsSender(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = model.items[index].message, previous = model.items[index - 1].message
        return current.sender.id != previous.sender.id || current.createdAt.timeIntervalSince(previous.createdAt) > 600
    }

    private func showsDayHeader(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(model.items[index].message.createdAt, inSameDayAs: model.items[index - 1].message.createdAt)
    }
}

private struct MessageBubble: View {
    let item: ChatThreadViewModel.Item
    let isMine: Bool
    let showsSender: Bool
    let isHost: Bool

    private var deliveryDescription: String {
        switch item.delivery {
        case .failed: String(localized: "chat.failed")
        case .sending: String(localized: "chat.sending")
        case .sent: ""
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            if isMine { Spacer(minLength: 48) }
            if !isMine {
                AvatarView(name: item.message.sender.displayName, url: item.message.sender.avatarURL, size: 28)
                    .opacity(showsSender ? 1 : 0)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if showsSender && !isMine {
                    HStack(spacing: 4) {
                        Text(item.message.sender.displayName).font(.caption.weight(.semibold))
                        if isHost { Text("chat.host_tag").rvLabelStyle(.caption2.monospaced().weight(.bold)).foregroundStyle(Theme.Palette.accentText) }
                    }
                    .foregroundStyle(Theme.Palette.inkSecondary)
                }
                Text(item.message.body)
                    .foregroundStyle(isMine ? Theme.Palette.canvas : Theme.Palette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(isMine ? Theme.Palette.ink : Theme.Palette.surface,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(Theme.Palette.ink, lineWidth: isMine ? 0 : Theme.Stroke.hairline))
                    .opacity(item.delivery == .sending ? 0.6 : 1)
                HStack(spacing: 4) {
                    if item.delivery == .failed {
                        Label("chat.failed", systemImage: "exclamationmark.circle.fill").foregroundStyle(Theme.Palette.danger)
                    } else {
                        Text(item.message.createdAt.formatted(date: .omitted, time: .shortened))
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.Palette.inkTertiary)
            }
            if !isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(item.message.sender.displayName): \(item.message.body)"))
        .accessibilityValue(Text(verbatim: deliveryDescription))
    }
}
