import PhotosUI
import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSession.self) private var session
    @State private var model: OnboardingViewModel?

    var body: some View {
        Group {
            if let model {
                OnboardingContent(model: model)
            } else {
                Color.clear
            }
        }
        .screenBackground()
        .onAppear {
            guard model == nil else { return }
            let store = OnboardingDraftStore(userID: env.config.isUITesting ? nil : session.userID)
            if env.config.isUITesting || env.config.resetMockState { store.clear() }
            model = OnboardingViewModel(profiles: env.profiles, store: store)
        }
    }
}

private struct OnboardingContent: View {
    @Bindable var model: OnboardingViewModel
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var nameFocused: Bool

    private var total: Int { OnboardingViewModel.Step.allCases.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    stepContent
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(model.step)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                  removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: model.step)
        .alert(Text("state.error.title"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text(model.error?.message ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button { model.back() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.icon)
                .opacity(model.step == .name ? 0 : 1)
                .disabled(model.step == .name)
                .accessibilityLabel(Text("action.back"))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.surfaceMuted)
                    Capsule().fill(Theme.Palette.ink)
                        .frame(width: proxy.size.width * model.progress)
                }
            }
            .frame(height: 6)
            .accessibilityElement()
            .accessibilityLabel(Text("onboarding.progress"))
            .accessibilityValue(Text("onboarding.progress.value \(model.step.rawValue + 1) \(total)"))
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, Theme.Spacing.s)
        .animation(reduceMotion ? nil : .spring(duration: 0.4), value: model.progress)
    }

    @ViewBuilder private var stepContent: some View {
        switch model.step {
        case .name:
            StepTitle(title: "onboarding.name.title", subtitle: "onboarding.name.subtitle")
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                TextField(text: $model.draft.displayName) { Text("onboarding.name.placeholder") }
                    .font(.title2.weight(.semibold))
                    .textContentType(.givenName)
                    .focused($nameFocused)
                    .submitLabel(.next)
                    .onSubmit { advance() }
                    .onAppear { nameFocused = true }
                    .padding(.horizontal, Theme.Spacing.l)
                    .frame(height: 64)
                    .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    .accessibilityIdentifier("onboarding.name")
                if let issue = model.nameIssue {
                    Text(issue.message).font(.footnote).foregroundStyle(Theme.Palette.danger)
                }
            }
        case .age:
            StepTitle(title: "onboarding.age.title", subtitle: "onboarding.age.subtitle")
            AgeConfirmation(isOn: $model.draft.confirmsAdult)
            Label("onboarding.age.note", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.inkSecondary)
        case .photo:
            StepTitle(title: "onboarding.photo.title", subtitle: "onboarding.photo.subtitle")
            AvatarPicker(name: model.draft.displayName, data: $model.photoData)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.l)
        case .interests:
            StepTitle(title: "onboarding.interests.title", subtitle: "onboarding.interests.subtitle")
            InterestPicker(selected: model.draft.interestIDs, toggle: model.toggleInterest)
        case .language:
            StepTitle(title: "onboarding.language.title", subtitle: "onboarding.language.subtitle")
            OptionList(items: AppLanguage.allCases.map { ($0.id, $0.displayName) }, selected: model.draft.language.id) { id in
                if let language = AppLanguage(rawValue: id) { model.draft.language = language }
            }
        case .neighborhood:
            StepTitle(title: "onboarding.neighborhood.title", subtitle: "onboarding.neighborhood.subtitle")
            OptionList(items: Neighborhood.all.map { ($0.id, $0.name) }, selected: model.draft.neighborhoodID,
                       identifierPrefix: "onboarding.neighborhood.") { id in
                model.draft.neighborhoodID = id
            }
        }
    }

    private var footer: some View {
        Button(action: advance) {
            if model.isSubmitting {
                ProgressView().tint(Theme.Palette.canvas)
            } else {
                Text(model.isLastStep ? "onboarding.finish" : (model.step == .photo && model.photoData == nil ? "action.skip" : "action.continue"))
            }
        }
        .buttonStyle(.primary)
        .disabled(!model.canContinue || model.isSubmitting)
        .accessibilityIdentifier("onboarding.continue")
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Palette.canvas.ignoresSafeArea())
    }

    private func advance() {
        Task {
            if let profile = await model.next() {
                Haptics.success()
                session.didCompleteOnboarding(profile)
            }
        }
    }
}

struct StepTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .rvHero(size: 32)
                .foregroundStyle(Theme.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.body).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Grouped single-choice list with a check on the selected row.
struct OptionList: View {
    let items: [(id: String, title: String)]
    let selected: String?
    var identifierPrefix = "option."
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isSelected = item.id == selected
                Button { onSelect(item.id) } label: {
                    HStack {
                        Text(item.title).font(.body.weight(isSelected ? .semibold : .regular))
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Theme.Palette.ink : Theme.Palette.surfaceStrong)
                    }
                    .foregroundStyle(Theme.Palette.ink)
                    .padding(.horizontal, Theme.Spacing.l)
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("\(identifierPrefix)\(item.id)")
                if index < items.count - 1 {
                    Divider().overlay(Theme.Palette.hairline).padding(.leading, Theme.Spacing.l)
                }
            }
        }
        .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .sensoryFeedback(.selection, trigger: selected)
    }
}

private struct AgeConfirmation: View {
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Theme.Palette.ink : Theme.Palette.inkTertiary)
                    .contentTransition(.symbolEffect(.replace))
                Text("onboarding.age.confirm").font(.body.weight(.semibold)).foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.l)
            .background(Theme.Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected, .isToggle] : .isToggle)
        .accessibilityIdentifier("onboarding.age")
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

struct InterestPicker: View {
    let selected: [String]
    let toggle: (String) -> Void

    var body: some View {
        FlowLayout(spacing: Theme.Spacing.s) {
            ForEach(Interest.all) { interest in
                FilterChip(title: interest.title, symbol: interest.category.symbol, tint: interest.category.tint,
                           isSelected: selected.contains(interest.id)) { toggle(interest.id) }
                    .accessibilityIdentifier("interest.\(interest.id)")
            }
        }
    }
}

struct AvatarPicker: View {
    let name: String
    @Binding var data: Data?
    @State private var item: PhotosPickerItem?
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 140, height: 140).clipShape(Circle())
                        .accessibilityHidden(true)
                } else {
                    AvatarView(name: name, url: nil, size: 140)
                }
                if isProcessing { ProgressView() }
            }
            PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                Label(data == nil ? "photo.choose" : "photo.change", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.secondaryCompact)
            if data != nil {
                Button("photo.remove", role: .destructive) { data = nil; item = nil }
                    .font(.subheadline)
            }
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            isProcessing = true
            Task {
                defer { isProcessing = false }
                if let raw = try? await newItem.loadTransferable(type: Data.self) {
                    data = ImageProcessing.preparedJPEG(from: raw, maxDimension: 800)
                }
            }
        }
    }
}

/// Re-encodes picked images: downsized, JPEG, and stripped of EXIF/GPS metadata.
enum ImageProcessing {
    static func preparedJPEG(from data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        // Re-rendering drops all original metadata, including location.
        return rendered.jpegData(compressionQuality: 0.82)
    }
}
