import SwiftUI
import CoreGraphics

@main
struct LottiApp: App {
    @AppStorage("triggerKeyCode") private var triggerKeyCode: Int = 0x36
    @StateObject private var store: Store
    private let coordinator: DictationCoordinator
    private let hotkey = HotkeyManager()
    private let pill = FloatingPillController()

    init() {
        AppFonts.register()
        // Real data only: the store starts empty and only ever contains the
        // user's actual dictations. `seedDemoDataIfEmpty` is intentionally not
        // called here — it's kept on `Store` for a possible future demo toggle.
        let store = Store()
        _store = StateObject(wrappedValue: store)
        let coord = DictationCoordinator(
            store: store,
            makeEngine: {
                DeepgramEngine(apiKey: Keychain.get("deepgram_api_key") ?? "",
                               keywords: Vocabulary.terms())
            },
            // Read the Anthropic key lazily, at dictation time, so a key entered
            // in Settings works on the next dictation without relaunching.
            makePolish: {
                Keychain.get("anthropic_api_key").map { PolishService(apiKey: $0) }
            },
            deepgramKeyPresent: {
                !(Keychain.get("deepgram_api_key") ?? "").isEmpty
            },
            pill: pill
        )
        coordinator = coord
        let storedKey = UserDefaults.standard.integer(forKey: "triggerKeyCode")
        hotkey.machine.triggerKey = CGKeyCode(storedKey == 0 ? 0x36 : storedKey)
        pill.onCancel = { Task { await coord.end(cancelled: true) } }
        pill.onConfirm = { Task { await coord.end(cancelled: false) } }
        hotkey.onEvent = { event in
            switch event {
            case .start: coord.begin()
            case .stop: Task { await coord.end(cancelled: false) }
            case .cancel: Task { await coord.end(cancelled: true) }
            case .lockToggle: coord.lockEngaged()
            }
        }
        hotkey.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await onLaunch() }
        }
        .windowStyle(.hiddenTitleBar)
    }

    /// Runs once when the main window appears: requests permissions (so macOS
    /// shows the prompts) and logs a diagnostics snapshot for the first run.
    @MainActor private func onLaunch() async {
        // Accessibility — required for BOTH the global hotkey tap and ⌘V paste.
        // prompt:true makes macOS show the prompt / open the Privacy pane.
        let ax = Permissions.accessibilityTrusted(prompt: true)
        // Microphone — requestAccess shows the mic prompt if undetermined.
        let mic = await Permissions.requestMicrophone()

        let deepgram = !(Keychain.get("deepgram_api_key") ?? "").isEmpty
        let anthropic = !(Keychain.get("anthropic_api_key") ?? "").isEmpty
        AppLog.log("Launch diagnostics —")
        AppLog.log("  microphone authorized: \(mic)")
        AppLog.log("  accessibility trusted: \(ax)")
        AppLog.log("  hotkey tap active: \(hotkey.isActive)")
        AppLog.log("  Deepgram key: \(deepgram ? "present" : "missing")")
        AppLog.log("  Anthropic key: \(anthropic ? "present" : "missing")")
        if !ax {
            AppLog.log("  ↳ Accessibility not yet granted — grant it, and the hotkey will go live WITHOUT a relaunch.")
        }
    }
}
