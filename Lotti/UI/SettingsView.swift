import SwiftUI
import AppKit

/// Settings, rebuilt as a centered modal card (presented by `RootView`).
///
/// This view renders only the *contents* of the card — a left sub-navigation
/// column over `#F7F5F2` and a white right content pane. `RootView` supplies
/// the surrounding white rounded card, its shadow, the dimmed scrim, and the
/// centering. `onClose` dismisses the modal (used by the top-right close
/// control; scrim taps are handled by `RootView`).
struct SettingsView: View {
    enum Pane: String, CaseIterable, Identifiable {
        case general = "General"
        case system = "System"
        case notetaker = "Notetaker"
        case keys = "Keys"
        case dictionary = "Dictionary"
        case permissions = "Permissions"
        case account = "Account"
        case dataPrivacy = "Data & Privacy"
        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general: "gearshape"
            case .system: "macwindow"
            case .notetaker: "record.circle"
            case .keys: "key"
            case .dictionary: "character.book.closed"
            case .permissions: "hand.raised"
            case .account: "person.crop.circle"
            case .dataPrivacy: "lock.shield"
            }
        }
    }

    var onClose: () -> Void = {}

    @EnvironmentObject var store: Store
    @StateObject private var settings = AppSettings()
    @State private var pane: Pane = .general
    @State private var isRecordingKey = false
    @State private var hoveredNav: String?
    @State private var showClearConfirm = false

    @State private var micAuthorized = false
    @State private var axTrusted = false
    @State private var vocabTerms: [String] = Vocabulary.terms()
    @State private var newTerm = ""
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    private let topGroup: [Pane] = [.general, .system, .notetaker, .keys, .dictionary, .permissions]
    private let accountGroup: [Pane] = [.account, .dataPrivacy]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            subNav
                .frame(width: 209)
                .frame(maxHeight: .infinity)
                .background(Color.figCardFill)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Color.figBorder).frame(width: 0.5)
                }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left sub-navigation

    private var subNav: some View {
        VStack(alignment: .leading, spacing: 2) {
            groupLabel("SETTINGS")
            ForEach(topGroup) { navRow($0) }

            Rectangle()
                .fill(Color.figBorder)
                .frame(height: 0.5)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)

            groupLabel("ACCOUNT")
            ForEach(accountGroup) { navRow($0) }

            Spacer(minLength: 0)

            Text("Lotti v0.1")
                .font(.gsRegular(11))
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 12)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.gsMedium(11))
            .tracking(1.1)
            .foregroundStyle(Color.figTextGrey)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 4)
    }

    private func navRow(_ p: Pane) -> some View {
        let isActive = pane == p
        let isHovered = hoveredNav == p.id
        return HStack(spacing: 9) {
            Image(systemName: p.systemImage)
                .font(.system(size: 13.5))
                .frame(width: 18)
            Text(p.rawValue)
                .font(.gsMedium(14.5))
            Spacer(minLength: 0)
        }
        .foregroundStyle(isActive ? Color.figTextPrimary : Color.figTextGrey)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.figNavActiveBg : (isHovered ? Color.figNavHoverBg : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { pane = p }
        .onHover { hovering in
            hoveredNav = hovering ? p.id : (hoveredNav == p.id ? nil : hoveredNav)
        }
    }

    // MARK: - Right content

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(pane.rawValue)
                    .font(.loraMedium(27))
                    .foregroundStyle(Color.figTextPrimary)

                switch pane {
                case .general: generalContent
                case .system: systemContent
                case .notetaker: notetakerContent
                case .keys: keysContent
                case .dictionary: dictionaryContent
                case .permissions: permissionsContent
                case .account: accountContent
                case .dataPrivacy: dataPrivacyContent
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 30)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.figTextGrey)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.figCardFill))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }

    // MARK: - General

    private var generalContent: some View {
        card {
            settingRow(label: "Shortcuts",
                       sub: "Hold \(KeyCodeNaming.name(for: settings.triggerKeyCode)) and speak") {
                ZStack {
                    changeButton(isRecordingKey ? "Press a key…" : "Change") {
                        isRecordingKey = true
                    }
                    TriggerKeyRecorder(isRecording: $isRecordingKey) { code in
                        settings.triggerKeyCode = code
                        // Take effect LIVE — the running HotkeyManager updates
                        // its trigger key without a relaunch.
                        NotificationCenter.default.post(name: .triggerKeyChanged, object: code)
                        isRecordingKey = false
                    }
                    .frame(width: 0, height: 0)
                }
            }
            hairline
            settingRow(label: "Microphone", sub: "Auto-detect (System Default)") {
                changeButton("Change") {}
            }
            hairline
            settingRow(label: "Dictation Language", sub: "English") {
                changeButton("Change") {}
            }
            hairline
            settingRow(label: "App Language", sub: "Interface language") {
                Picker("", selection: $settings.appLanguage) {
                    Text("English").tag("English")
                }
                .labelsHidden()
                .frame(width: 130)
            }
        }
    }

    // MARK: - System

    private var systemContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                toggleRow(label: "Launch app at login",
                          sub: "Open Lotti automatically when you sign in",
                          isOn: $settings.launchAtLogin)
                hairline
                toggleRow(label: "Show floating pill while dictating",
                          sub: "A small pill appears while you speak",
                          isOn: $settings.showFloatingPill)
                hairline
                toggleRow(label: "Show app in Dock",
                          sub: "Keep the Lotti icon in your Dock",
                          isOn: $settings.showInDock)
            }
            sectionHeading("Sound")
            card {
                toggleRow(label: "Dictation & notification sounds",
                          sub: "Play sounds for dictation and alerts",
                          isOn: $settings.soundsEnabled)
                hairline
                toggleRow(label: "Mute music while dictating",
                          sub: "Pause other audio while you speak",
                          isOn: $settings.muteMusicWhileDictating)
            }
        }
    }

    // MARK: - Notetaker

    private var notetakerContent: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Notetaker settings coming soon.")
                    .font(.gsMedium(15))
                    .foregroundStyle(Color.figTextPrimary)
                Text("Meeting capture and note-taking controls will appear here.")
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.figTextGrey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Keys

    private var keysContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            card {
                KeyRow(title: "Deepgram API key", account: "deepgram_api_key")
                hairline
                KeyRow(title: "Anthropic API key", account: "anthropic_api_key")
                hairline
                settingRow(label: "Transcription engine", sub: "Deepgram") {
                    Text("Active")
                        .font(.gsMedium(12))
                        .foregroundStyle(Color.appTeal)
                }
                hairline
                settingRow(label: "On-device (Parakeet)", sub: "Coming soon") {
                    Text("Coming soon")
                        .font(.gsMedium(12))
                        .foregroundStyle(Color.figTextGrey)
                }
                .opacity(0.5)
                hairline
                toggleRow(label: "Polish with AI",
                          sub: "Clean up dictated text automatically",
                          isOn: $settings.polishEnabled)
            }
            Text("Your keys are stored securely in your Mac's Keychain and never leave your device.")
                .font(.gsRegular(12))
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Dictionary (custom vocabulary)

    private var dictionaryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add names, brands, or jargon so Lotti transcribes them correctly.")
                .font(.gsRegular(13))
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 4)

            card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        TextField("e.g. Wispr Flow", text: $newTerm)
                            .textFieldStyle(.roundedBorder)
                            .font(.gsRegular(14))
                            .onSubmit(addTerm)
                        Button(action: addTerm) {
                            Text("Add")
                                .font(.gsMedium(13))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.appTeal)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 4)

                    if vocabTerms.isEmpty {
                        Text("No custom words yet.")
                            .font(.gsRegular(13))
                            .foregroundStyle(Color.figTextGrey)
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(vocabTerms.enumerated()), id: \.offset) { index, term in
                                if index > 0 { hairline }
                                HStack(spacing: 12) {
                                    Text(term)
                                        .font(.gsMedium(14))
                                        .foregroundStyle(Color.figTextPrimary)
                                    Spacer(minLength: 12)
                                    Button(action: { removeTerm(at: index) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.figTextGrey)
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(Color.figNavActiveBg))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }

            Text("Each term is boosted in Deepgram so it's recognised more reliably. Takes effect on your next dictation or recording.")
                .font(.gsRegular(12))
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 4)
        }
        .onAppear { vocabTerms = Vocabulary.terms() }
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var terms = vocabTerms
        terms.append(trimmed)
        Vocabulary.set(terms)
        vocabTerms = Vocabulary.terms()
        newTerm = ""
        AppLog.log("[Lotti] vocabulary: added \"\(trimmed)\" (\(vocabTerms.count) total)")
    }

    private func removeTerm(at index: Int) {
        guard vocabTerms.indices.contains(index) else { return }
        var terms = vocabTerms
        let removed = terms.remove(at: index)
        Vocabulary.set(terms)
        vocabTerms = Vocabulary.terms()
        AppLog.log("[Lotti] vocabulary: removed \"\(removed)\" (\(vocabTerms.count) total)")
    }

    // MARK: - Permissions

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            card {
                settingRow(label: "Microphone",
                           sub: micAuthorized ? "Granted" : "Not granted — required to record speech") {
                    HStack(spacing: 10) {
                        statusDot(micAuthorized)
                        changeButton("Grant microphone") {
                            Task {
                                _ = await Permissions.requestMicrophone()
                                refreshPermissionStatus()
                            }
                        }
                    }
                }
                hairline
                settingRow(label: "Accessibility",
                           sub: axTrusted ? "Granted" : "Not granted — required for the hotkey and paste") {
                    HStack(spacing: 10) {
                        statusDot(axTrusted)
                        changeButton("Open Accessibility settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
            HStack {
                changeButton("Re-check") { refreshPermissionStatus() }
                Spacer()
            }
            .padding(.horizontal, 4)
            Text("Microphone lets Lotti hear you. Accessibility lets Lotti detect the global hotkey and paste your text. After granting Accessibility, the hotkey activates without relaunching.")
                .font(.gsRegular(12))
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 4)
        }
        .onAppear { refreshPermissionStatus() }
    }

    private func statusDot(_ ok: Bool) -> some View {
        Circle()
            .fill(ok ? Color.appTeal : Color.red.opacity(0.7))
            .frame(width: 9, height: 9)
    }

    private func refreshPermissionStatus() {
        axTrusted = Permissions.accessibilityTrusted(prompt: false)
        Task {
            let mic = await Permissions.microphoneAuthorized()
            await MainActor.run { micAuthorized = mic }
        }
    }

    // MARK: - Account

    private var accountContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                settingRow(label: "Profile picture", sub: "Shown across Lotti") {
                    Circle()
                        .fill(Color.figNavActiveBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.figTextGrey)
                        )
                }
                hairline
                settingRow(label: "First name", sub: "How we address you") {
                    TextField("First name", text: $settings.firstName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                hairline
                settingRow(label: "Last name", sub: "Optional") {
                    TextField("Last name", text: $settings.lastName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                hairline
                settingRow(label: "Email", sub: "Your account email") {
                    Text(settings.accountEmail)
                        .font(.gsRegular(13))
                        .foregroundStyle(Color.figTextGrey)
                }
            }
            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Save")
                        .font(.gsMedium(13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.appTeal)
                        )
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Sign out") {}
                    .buttonStyle(.plain)
                    .font(.gsMedium(13))
                    .foregroundStyle(Color.figTextGrey)
                Button("Delete account") {}
                    .buttonStyle(.plain)
                    .font(.gsMedium(13))
                    .foregroundStyle(Color.red.opacity(0.8))
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Data & Privacy

    private var dataPrivacyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                settingRow(label: "Clear all dictation data",
                           sub: "Permanently remove every stored dictation") {
                    Button(action: { showClearConfirm = true }) {
                        Text("Clear")
                            .font(.gsMedium(13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.red.opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                }
                hairline
                settingRow(label: "Re-run onboarding",
                           sub: "Show the first-run setup flow again") {
                    changeButton("Reset onboarding") {
                        onClose()
                        onboardingComplete = false
                    }
                }
            }
            Text("All your dictations are stored locally on this Mac.")
                .font(.gsRegular(12))
                .foregroundStyle(Color.figTextGrey)
                .padding(.horizontal, 4)
        }
        .alert("Clear all dictation data?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { store.clearAll() }
        } message: {
            Text("This permanently removes every stored dictation from this Mac. This cannot be undone.")
        }
    }

    // MARK: - Reusable pieces

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.figCardFill)
            )
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.gsSemibold(13))
            .foregroundStyle(Color.figTextGrey)
            .padding(.horizontal, 4)
    }

    private func settingRow<Control: View>(label: String, sub: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.gsSemibold(14.5))
                    .foregroundStyle(Color.figTextPrimary)
                Text(sub)
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.figTextGrey)
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 13)
    }

    private func toggleRow(label: String, sub: String, isOn: Binding<Bool>) -> some View {
        settingRow(label: label, sub: sub) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.appTeal)
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.figBorder)
            .frame(height: 0.5)
    }

    private func changeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.gsMedium(13))
                .foregroundStyle(Color.figTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.figNavActiveBg)
                )
        }
        .buttonStyle(.plain)
    }
}

/// A single API-key row. Shows a "Saved" state with a Replace affordance when a
/// key already lives in the Keychain, and writes new values via `Keychain.set`.
private struct KeyRow: View {
    let title: String
    let account: String

    @State private var editing = false
    @State private var value = ""
    @State private var hasKey = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.gsSemibold(14.5))
                    .foregroundStyle(Color.figTextPrimary)
                Text(hasKey && !editing ? "•••••• Saved" : "Stored securely in your Keychain")
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.figTextGrey)
            }
            Spacer(minLength: 12)

            if hasKey && !editing {
                Button {
                    editing = true
                    value = ""
                } label: {
                    Text("Replace")
                        .font(.gsMedium(13))
                        .foregroundStyle(Color.figTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.figNavActiveBg)
                        )
                }
                .buttonStyle(.plain)
            } else {
                SecureField("Enter key", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                    .onSubmit(commit)
                Button("Save", action: commit)
            }
        }
        .padding(.vertical, 13)
        .onAppear { hasKey = Keychain.get(account) != nil }
    }

    private func commit() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? Keychain.set(trimmed, for: account)
        value = ""
        editing = false
        hasKey = true
    }
}
