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

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    stepContent
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, Theme.Spacing.l)
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
            Button {
                model.back()
            } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
            }
            .opacity(model.step == .name ? 0 : 1)
            .disabled(model.step == .name)
            .accessibilityLabel(Text("action.back"))

            ProgressView(value: model.progress)
                .tint(Theme.Palette.brand)
                .accessibilityLabel(Text("onboarding.progress"))
                .accessibilityValue(Text("onboarding.progress.value \(model.step.rawValue + 1) \(OnboardingViewModel.Step.allCases.count)"))
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Theme.Spacing.s)
    }

    @ViewBuilder private var stepContent: some View {
        switch model.step {
        case .name:
            StepTitle(title: "onboarding.name.title", subtitle: "onboarding.name.subtitle")
            TextField(text: $model.draft.displayName) { Text("onboarding.name.placeholder") }
                .textContentType(.givenName)
                .font(.title3)
                .padding(Theme.Spacing.l)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .focused($nameFocused)
                .submitLabel(.next)
                .onSubmit { advance() }
                .onAppear { nameFocused = true }
                .accessibilityIdentifier("onboarding.name")
            if let issue = model.nameIssue {
                Text(issue.message).font(.footnote).foregroundStyle(Theme.Palette.danger)
            }
        case .age:
            StepTitle(title: "onboarding.age.title", subtitle: "onboarding.age.subtitle")
            Toggle(isOn: $model.draft.confirmsAdult) {
                Text("onboarding.age.confirm").font(.body.weight(.semibold))
            }
            .tint(Theme.Palette.brand)
            .rvCard()
            .accessibilityIdentifier("onboarding.age")
            Label("onboarding.age.note", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.inkSecondary)
        case .photo:
            StepTitle(title: "onboarding.photo.title", subtitle: "onboarding.photo.subtitle")
            AvatarPicker(name: model.draft.displayName, data: $model.photoData)
                .frame(maxWidth: .infinity)
        case .interests:
            StepTitle(title: "onboarding.interests.title", subtitle: "onboarding.interests.subtitle")
            InterestPicker(selected: model.draft.interestIDs, toggle: model.toggleInterest)
        case .language:
            StepTitle(title: "onboarding.language.title", subtitle: "onboarding.language.subtitle")
            ForEach(AppLanguage.allCases) { language in
                SelectableRow(title: language.displayName, isSelected: model.draft.language == language) {
                    model.draft.language = language
                }
            }
        case .neighborhood:
            StepTitle(title: "onboarding.neighborhood.title", subtitle: "onboarding.neighborhood.subtitle")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
                ForEach(Neighborhood.all) { hood in
                    FilterChip(title: hood.name, symbol: "mappin", tint: Theme.Palette.brand,
                               isSelected: model.draft.neighborhoodID == hood.id) {
                        model.draft.neighborhoodID = hood.id
                    }
                    .accessibilityIdentifier("onboarding.neighborhood.\(hood.id)")
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button(action: advance) {
                if model.isSubmitting {
                    ProgressView().tint(Theme.Palette.onBrand)
                } else {
                    Text(model.isLastStep ? "onboarding.finish" : (model.step == .photo && model.photoData == nil ? "action.skip" : "action.continue"))
                }
            }
            .buttonStyle(.primary)
            .disabled(!model.canContinue || model.isSubmitting)
            .accessibilityIdentifier("onboarding.continue")
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Palette.canvas)
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
            Text(title).font(.rvTitle).foregroundStyle(Theme.Palette.ink).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.body).foregroundStyle(Theme.Palette.inkSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SelectableRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.Palette.ink)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.Palette.brand : Theme.Palette.hairline)
            }
            .rvCard()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
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
