import SwiftUI
import AppKit

/// First-run onboarding. A centered, on-brand paged flow shown full-window by
/// `RootView` while `onboardingComplete == false`. It collects the user's name,
/// nudges them through the mic + Accessibility permissions, stores their own
/// Deepgram / Anthropic keys in the Keychain, and lets them pick a push-to-talk
/// trigger key, so the app is shareable: a friend installs it, onboards, and
/// sees their OWN name and uses their OWN keys.
struct OnboardingView: View {
    /// Set true on the final step; `RootView` swaps in the main app (no relaunch).
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("firstName") private var firstName = ""
    @AppStorage("triggerKeyCode") private var triggerKeyCode: Int = 0x36

    private enum Step: Int, CaseIterable {
        case welcome, name, permissions, keys, trigger, done
    }

    @State private var step: Step = .welcome

    // Keys (loaded from / saved to the Keychain).
    @State private var deepgramKey = ""
    @State private var anthropicKey = ""

    // Permission status.
    @State private var micAuthorized = false
    @State private var axTrusted = false

    // Trigger-key recorder.
    @State private var isRecordingKey = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                content
                    .frame(width: 520)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.figBorder, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 30, y: 14)

                Spacer(minLength: 0)

                stepDots
                    .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            deepgramKey = Keychain.get("deepgram_api_key") ?? ""
            anthropicKey = Keychain.get("anthropic_api_key") ?? ""
            refreshPermissionStatus()
        }
    }

    // MARK: - Background (cream + subtle ShaderGradient accent)

    private var background: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            BlobGradient()
                .opacity(0.12)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:     welcomeStep
        case .name:        nameStep
        case .permissions: permissionsStep
        case .keys:        keysStep
        case .trigger:     triggerStep
        case .done:        doneStep
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            BrandMark(size: 52)
            VStack(spacing: 10) {
                Text("Welcome to Lotti")
                    .font(.loraMedium(34))
                    .foregroundStyle(Color.figTextPrimary)
                Text("Private, fast voice-to-text, right on your Mac.")
                    .font(.gsRegular(15))
                    .foregroundStyle(Color.figTextGrey)
                    .multilineTextAlignment(.center)
            }
            darkButton("Get started") { advance() }
                .padding(.top, 6)
        }
    }

    // MARK: - Step 2: Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("What should we call you?",
                       sub: "We'll use this to greet you around the app.")
            TextField("Your first name", text: $firstName)
                .textFieldStyle(.plain)
                .font(.gsRegular(17))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.figCardFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.figBorder, lineWidth: 0.5))
                .onSubmit { advance() }
            navButtons(continueEnabled: true)
        }
    }

    // MARK: - Step 3: Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader("Grant a couple of permissions",
                       sub: "Lotti needs these to hear you and type where your cursor is.")

            VStack(spacing: 0) {
                permissionRow(
                    title: "Microphone",
                    detail: micAuthorized ? "Granted" : "Needed to record your speech.",
                    granted: micAuthorized,
                    button: "Grant microphone") {
                        Task {
                            _ = await Permissions.requestMicrophone()
                            refreshPermissionStatus()
                        }
                    }
                hairline
                permissionRow(
                    title: "Accessibility",
                    detail: axTrusted ? "Granted" : "Needed for the global hotkey and pasting your text.",
                    granted: axTrusted,
                    button: "Open Accessibility settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.figCardFill))

            HStack {
                secondaryButton("Re-check") { refreshPermissionStatus() }
                Spacer()
            }

            if !(micAuthorized && axTrusted) {
                warning("You can continue for now, but Lotti won't fully work until both are granted. Accessibility may need you to re-open the app on some setups.")
            }

            navButtons(continueEnabled: true, skip: true)
        }
    }

    private func permissionRow(title: String, detail: String, granted: Bool,
                               button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(granted ? Color.appTeal : Color.red.opacity(0.7))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.gsSemibold(14.5))
                    .foregroundStyle(Color.figTextPrimary)
                Text(detail)
                    .font(.gsRegular(12.5))
                    .foregroundStyle(Color.figTextGrey)
            }
            Spacer(minLength: 12)
            secondaryButton(button, action: action)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Step 4: Keys

    private var keysStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("Add your keys",
                       sub: "Lotti transcribes with Deepgram and (optionally) cleans up with Anthropic.")

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    keyField(label: "Deepgram API key", placeholder: "paste your key here", text: $deepgramKey)
                    deepgramHelp
                }
                keyField(label: "Anthropic API key (optional)", placeholder: "sk-ant-…, for AI cleanup", text: $anthropicKey)
            }

            Text("Anthropic is optional, only for AI cleanup. Your keys stay in your Mac's Keychain and never leave your device.")
                .font(.gsRegular(12))
                .foregroundStyle(Color.figTextGrey)
                .fixedSize(horizontal: false, vertical: true)

            if deepgramKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warning("You'll need a Deepgram key to transcribe, you can add it later in Settings.")
            }

            navButtons(continueEnabled: true, skip: true) {
                saveKeys()
                advance()
            }
        }
    }

    /// Actionable how-to under the Deepgram field: a tappable link to where the
    /// key is created, plus the exact steps. Important for the open-source build
    /// where every user must bring their own free key.
    private var deepgramHelp: some View {
        VStack(alignment: .leading, spacing: 3) {
            Link(destination: URL(string: "https://console.deepgram.com/signup")!) {
                HStack(spacing: 4) {
                    Text("Don't have a key? Create one free")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.gsSemibold(12))
                .foregroundStyle(Color.appTeal)
            }
            .buttonStyle(.plain)
            Text("Sign up (free credit) → open API Keys → Create a Key → copy it → paste above.")
                .font(.gsRegular(11.5))
                .foregroundStyle(Color.figTextGrey)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func keyField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.gsSemibold(13.5))
                .foregroundStyle(Color.figTextPrimary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.gsRegular(15))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.figCardFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.figBorder, lineWidth: 0.5))
        }
    }

    // MARK: - Step 5: Trigger key

    private var triggerStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeader("Pick your push-to-talk key",
                       sub: "Hold it anywhere and speak; release to insert your words.")

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trigger key")
                        .font(.gsSemibold(14.5))
                        .foregroundStyle(Color.figTextPrimary)
                    Text("Currently \(KeyCodeNaming.name(for: triggerKeyCode))")
                        .font(.gsRegular(13))
                        .foregroundStyle(Color.figTextGrey)
                }
                Spacer(minLength: 12)
                ZStack {
                    secondaryButton(isRecordingKey ? "Press a key…" : "Change") {
                        isRecordingKey = true
                    }
                    TriggerKeyRecorder(isRecording: $isRecordingKey) { code in
                        triggerKeyCode = code
                        NotificationCenter.default.post(name: .triggerKeyChanged, object: code)
                        isRecordingKey = false
                    }
                    .frame(width: 0, height: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.figCardFill))

            navButtons(continueEnabled: true)
        }
    }

    // MARK: - Step 6: Done

    private var doneStep: some View {
        VStack(spacing: 22) {
            BrandMark(size: 46)
            VStack(spacing: 10) {
                Text(firstName.trimmingCharacters(in: .whitespaces).isEmpty
                     ? "You're all set!"
                     : "You're all set, \(firstName)!")
                    .font(.loraMedium(30))
                    .foregroundStyle(Color.figTextPrimary)
                    .multilineTextAlignment(.center)
                Text("Hold \(KeyCodeNaming.name(for: triggerKeyCode)) anywhere and speak, your words appear wherever your cursor is.")
                    .font(.gsRegular(15))
                    .foregroundStyle(Color.figTextGrey)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            darkButton("Start using Lotti") {
                saveKeys()
                onboardingComplete = true
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Shared pieces

    private func stepHeader(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.loraMedium(26))
                .foregroundStyle(Color.figTextPrimary)
            Text(sub)
                .font(.gsRegular(14.5))
                .foregroundStyle(Color.figTextGrey)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func warning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.appOrange)
            Text(text)
                .font(.gsRegular(12.5))
                .foregroundStyle(Color.figTextGrey)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hairline: some View {
        Rectangle().fill(Color.figBorder).frame(height: 0.5)
    }

    /// Back / Continue row. `skip` shows a "Skip for now" affordance.
    @ViewBuilder
    private func navButtons(continueEnabled: Bool, skip: Bool = false,
                            continueAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            if step != .welcome {
                secondaryButton("Back") { goBack() }
            }
            Spacer()
            if skip {
                Button("Skip for now") { advance() }
                    .buttonStyle(.plain)
                    .font(.gsMedium(13))
                    .foregroundStyle(Color.figTextGrey)
            }
            darkButton("Continue") {
                if let continueAction { continueAction() } else { advance() }
            }
            .opacity(continueEnabled ? 1 : 0.5)
            .disabled(!continueEnabled)
        }
        .padding(.top, 4)
    }

    private func darkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.gsMedium(14))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: 0x1A1A1A)))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.gsMedium(13))
                .foregroundStyle(Color.figTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.figNavActiveBg))
        }
        .buttonStyle(.plain)
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(s == step ? Color.figTextPrimary : Color.figBorder)
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: - Navigation & side effects

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.18)) { step = next }
        }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.18)) { step = prev }
        }
    }

    private func saveKeys() {
        let dg = deepgramKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dg.isEmpty { try? Keychain.set(dg, for: "deepgram_api_key") }
        let an = anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !an.isEmpty { try? Keychain.set(an, for: "anthropic_api_key") }
    }

    private func refreshPermissionStatus() {
        axTrusted = Permissions.accessibilityTrusted(prompt: false)
        Task {
            let mic = await Permissions.microphoneAuthorized()
            await MainActor.run { micAuthorized = mic }
        }
    }
}
