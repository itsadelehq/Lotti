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
        // Seeded exactly once here, at app launch — never inside a view's
        // body/onAppear, which would re-run on every navigation.
        let store = Store()
        store.seedDemoDataIfEmpty()
        _store = StateObject(wrappedValue: store)
        let coord = DictationCoordinator(
            store: store,
            makeEngine: {
                DeepgramEngine(apiKey: Keychain.get("deepgram_api_key") ?? "")
            },
            polish: Keychain.get("anthropic_api_key").map { PolishService(apiKey: $0) },
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
            case .lockToggle: break
            }
        }
        hotkey.start()
    }

    var body: some Scene {
        WindowGroup { RootView().environmentObject(store) }
            .windowStyle(.hiddenTitleBar)
    }
}
