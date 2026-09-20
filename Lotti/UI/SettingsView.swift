import SwiftUI
import AppKit

struct SettingsView: View {
    enum Pane: String, CaseIterable, Identifiable {
        case general = "General"
        case system = "System"
        case permissions = "Permissions"
        case keys = "Keys"
        case about = "About"
        var id: String { rawValue }
    }

    @StateObject private var settings = AppSettings()
    @State private var pane: Pane = .general
    @State private var isRecordingKey = false
    @State private var micAuthorized = false
    @State private var axTrusted = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            subNav
                .frame(width: 230)
            Divider().overlay(Color.appDivider)
            detail
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await refreshPermissions() }
    }

    // MARK: Left sub-navigation

    private var subNav: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SETTINGS")
                .font(.gsMedium(11))
                .tracking(1.2)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            ForEach(Pane.allCases) { p in
                subNavRow(p)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func subNavRow(_ p: Pane) -> some View {
        HStack {
            Text(p.rawValue)
                .font(.gsMedium(15))
            Spacer()
        }
        .foregroundStyle(pane == p ? Color.appTextPrimary : Color(hex: 0x3A3A38))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(pane == p ? Color(hex: 0xECEBE6) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { pane = p }
    }

    // MARK: Right detail

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(pane.rawValue)
                    .font(.gsBold(30))
                    .foregroundStyle(Color.appTextPrimary)

                switch pane {
                case .general: generalCard
                case .system: systemCard
                case .permissions: permissionsCard
                case .keys: keysCard
                case .about: aboutCard
                }
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    // MARK: Cards

    private var generalCard: some View {
        settingsCard {
            settingRow(label: "Shortcuts",
                       sub: "Hold \(KeyCodeNaming.name(for: settings.triggerKeyCode)) and speak") {
                ZStack {
                    ghostButton(isRecordingKey ? "Press a key…" : "Change") {
                        isRecordingKey = true
                    }
                    TriggerKeyRecorder(isRecording: $isRecordingKey) { code in
                        settings.triggerKeyCode = code
                        isRecordingKey = false
                    }
                    .frame(width: 0, height: 0)
                }
            }
            hairline
            settingRow(label: "Microphone", sub: "Auto-detect (System Default)") {
                ghostButton("Change") {}
            }
            hairline
            settingRow(label: "Dictation Language", sub: "English") {
                ghostButton("Change") {}
            }
        }
    }

    private var systemCard: some View {
        settingsCard {
            settingRow(label: "Transcription engine", sub: "Deepgram") {
                Text("Active")
                    .font(.gsMedium(12))
                    .foregroundStyle(Color.appTeal)
            }
            hairline
            settingRow(label: "On-device (Parakeet)", sub: "Coming soon") {
                Text("Coming soon")
                    .font(.gsMedium(12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .opacity(0.5)
            hairline
            settingRow(label: "Polish with AI", sub: "Clean up dictated text automatically") {
                Toggle("", isOn: $settings.polishEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color.appTeal)
            }
        }
    }

    private var permissionsCard: some View {
        settingsCard {
            settingRow(label: "Microphone",
                       sub: micAuthorized ? "Granted" : "Not granted") {
                if micAuthorized {
                    statusBadge(true)
                } else {
                    ghostButton("Request") {
                        Task { micAuthorized = await Permissions.requestMicrophone() }
                    }
                }
            }
            hairline
            settingRow(label: "Accessibility",
                       sub: axTrusted ? "Granted" : "Not granted") {
                if axTrusted {
                    statusBadge(true)
                } else {
                    ghostButton("Open Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
            hairline
            settingRow(label: "Re-check permissions",
                       sub: "Refresh the current status") {
                ghostButton("Re-check") { Task { await refreshPermissions() } }
            }
        }
    }

    private var keysCard: some View {
        settingsCard {
            KeyRow(title: "Deepgram API key", account: "deepgram_api_key")
            hairline
            KeyRow(title: "Anthropic API key", account: "anthropic_api_key")
        }
    }

    private var aboutCard: some View {
        settingsCard {
            settingRow(label: "Lotti", sub: "Voice dictation, polished.") {
                Text("Lotti v0.1")
                    .font(.gsMedium(12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            hairline
            VStack(alignment: .leading, spacing: 4) {
                Text("Speak naturally and Lotti transcribes and polishes your words into clean text, anywhere on your Mac.")
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Reusable pieces

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appInsightCard)
            )
    }

    private func settingRow<Control: View>(label: String, sub: String,
                                            @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.gsMedium(15))
                    .foregroundStyle(Color.appTextPrimary)
                Text(sub)
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 14)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.appDivider)
            .frame(height: 1)
    }

    private func ghostButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.gsMedium(13))
                .foregroundStyle(Color.appTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ ok: Bool) -> some View {
        Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .foregroundStyle(ok ? Color.appTeal : .orange)
    }

    private func refreshPermissions() async {
        micAuthorized = await Permissions.microphoneAuthorized()
        axTrusted = Permissions.accessibilityTrusted(prompt: false)
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
                    .font(.gsMedium(15))
                    .foregroundStyle(Color.appTextPrimary)
                Text(hasKey && !editing ? "•••••• Saved" : "Stored securely in your Keychain")
                    .font(.gsRegular(13))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer(minLength: 12)

            if hasKey && !editing {
                Button {
                    editing = true
                    value = ""
                } label: {
                    Text("Replace")
                        .font(.gsMedium(13))
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.black.opacity(0.15), lineWidth: 1)
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
        .padding(.vertical, 14)
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
