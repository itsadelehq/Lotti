import SwiftUI
import AppKit

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    @State private var isRecordingKey = false
    @State private var deepgramKey = ""
    @State private var anthropicKey = ""
    @State private var micAuthorized = false
    @State private var axTrusted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.gsBold(30))
                    .foregroundStyle(Color.appTextPrimary)

                triggerKeySection
                engineSection
                polishSection
                apiKeysSection
                permissionsSection
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .task { await refreshPermissions() }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.gsMedium(13)).foregroundStyle(Color.appTextSecondary)
            VStack(alignment: .leading, spacing: 14) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardStyle()
        }
    }

    private var triggerKeySection: some View {
        section("Trigger key") {
            HStack {
                Text(KeyCodeNaming.name(for: settings.triggerKeyCode))
                    .font(.gsRegular(14)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                Button(isRecordingKey ? "Press a key…" : "Change") {
                    isRecordingKey = true
                }
                .buttonStyle(.bordered)
                TriggerKeyRecorder(isRecording: $isRecordingKey) { code in
                    settings.triggerKeyCode = code
                    isRecordingKey = false
                }
                .frame(width: 0, height: 0)
            }
        }
    }

    private var engineSection: some View {
        section("Transcription engine") {
            HStack {
                Label("Deepgram", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.appTeal)
                Spacer()
                Text("Active").font(.gsMedium(12)).foregroundStyle(Color.appTextSecondary)
            }
            HStack {
                Label("Parakeet", systemImage: "circle")
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("Coming soon").font(.gsMedium(12)).foregroundStyle(Color.appTextSecondary)
            }
            .opacity(0.5)
        }
    }

    private var polishSection: some View {
        section("Polish") {
            Toggle("Polish dictated text with AI", isOn: $settings.polishEnabled)
                .font(.gsRegular(14))
        }
    }

    private var apiKeysSection: some View {
        section("API keys") {
            apiKeyRow(title: "Deepgram API key", account: "deepgram_api_key", value: $deepgramKey)
            Divider()
            apiKeyRow(title: "Anthropic API key", account: "anthropic_api_key", value: $anthropicKey)
        }
    }

    private func apiKeyRow(title: String, account: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.gsRegular(13)).foregroundStyle(Color.appTextPrimary)
                Spacer()
                if Keychain.get(account) != nil {
                    Text("••• set").font(.gsRegular(12)).foregroundStyle(Color.appTextSecondary)
                }
            }
            HStack {
                SecureField("Enter key", text: value)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    if !value.wrappedValue.isEmpty {
                        try? Keychain.set(value.wrappedValue, for: account)
                        value.wrappedValue = ""
                    }
                }
                Button("Clear") { Keychain.delete(account) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var permissionsSection: some View {
        section("Permissions") {
            permissionRow(title: "Microphone", granted: micAuthorized) {
                Task { micAuthorized = await Permissions.requestMicrophone() }
            }
            permissionRow(title: "Accessibility", granted: axTrusted) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Button("Re-check") { Task { await refreshPermissions() } }
                .buttonStyle(.bordered)
        }
    }

    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? Color.appTeal : .orange)
            Text(title).font(.gsRegular(14)).foregroundStyle(Color.appTextPrimary)
            Spacer()
            if !granted {
                Button("Grant") { action() }.buttonStyle(.bordered)
            }
        }
    }

    private func refreshPermissions() async {
        micAuthorized = await Permissions.microphoneAuthorized()
        axTrusted = Permissions.accessibilityTrusted(prompt: false)
    }
}
