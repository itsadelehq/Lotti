import AppKit
import CoreGraphics
import ApplicationServices

enum HotkeyEvent { case start, stop, lockToggle, cancel }

extension Notification.Name {
    /// Posted (object: Int key code) when the trigger key changes in Settings,
    /// so the live HotkeyManager updates without a relaunch.
    static let triggerKeyChanged = Notification.Name("lotti.triggerKeyChanged")
}

final class HotkeyStateMachine {
    var triggerKey: CGKeyCode = 0x36 // right command
    private let space: CGKeyCode = 0x31
    private(set) var isRecording = false
    private(set) var isLocked = false

    func handle(keyCode: CGKeyCode, isDown: Bool, spaceDown: Bool) -> HotkeyEvent? {
        if keyCode == space, isDown, isRecording, !isLocked {
            isLocked = true; return .lockToggle
        }
        guard keyCode == triggerKey else { return nil }
        if isDown {
            if isRecording && isLocked { // second press ends locked session
                isRecording = false; isLocked = false; return .stop
            }
            isRecording = true; return .start
        } else { // key up
            if isLocked { return nil } // hands-free: ignore release
            if isRecording { isRecording = false; return .stop }
            return nil
        }
    }
}

/// Owns the global CGEventTap that drives push-to-talk.
///
/// The tap can only be created once Accessibility is granted — `CGEvent.tapCreate`
/// returns nil otherwise. To make the app usable WITHOUT a relaunch after the
/// user grants access, we retry: on `NSApplication.didBecomeActiveNotification`
/// and on a short repeating timer, both of which stop once the tap exists and
/// `AXIsProcessTrusted()` is true. `isActive` is published so the UI can reflect
/// whether the hotkey is live.
final class HotkeyManager: ObservableObject {
    var onEvent: ((HotkeyEvent) -> Void)?
    let machine = HotkeyStateMachine()

    /// True once the CGEventTap is created (i.e. Accessibility granted and the
    /// global hotkey is live). Observable so Settings can reflect the state.
    @Published private(set) var isActive = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var pressedKeys = Set<CGKeyCode>()
    private let spaceKey: CGKeyCode = 0x31

    /// Whether "hold key + spacebar to lock (hands-free)" is opt-in enabled.
    /// Default OFF so a stray spacebar press during dictation can never lock the
    /// session and swallow the key release (which used to split/lose speech).
    fileprivate var handsFreeLockEnabled: Bool {
        UserDefaults.standard.bool(forKey: "handsFreeLock")
    }

    func start() {
        // Live trigger-key updates from Settings (no relaunch needed).
        NotificationCenter.default.addObserver(
            forName: .triggerKeyChanged, object: nil, queue: .main) { [weak self] note in
            guard let code = note.object as? Int else { return }
            self?.machine.triggerKey = CGKeyCode(code)
            AppLog.log("Hotkey trigger key updated live → keyCode \(code)")
        }
        attemptCreateTap()
        if !isActive {
            AppLog.log("Hotkey tap NOT created (Accessibility not granted yet) — will retry on activation/timer")
            // Retry when the app regains focus (e.g. after user grants access
            // in System Settings and returns to Lotti).
            NotificationCenter.default.addObserver(
                self, selector: #selector(appDidBecomeActive),
                name: NSApplication.didBecomeActiveNotification, object: nil)
            // And a short repeating timer as a belt-and-braces fallback.
            let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.attemptCreateTap()
            }
            RunLoop.main.add(timer, forMode: .common)
            retryTimer = timer
        }
    }

    @objc private func appDidBecomeActive() {
        attemptCreateTap()
    }

    /// Attempts to (re)create the event tap. No-op once active. Stops the retry
    /// machinery once the tap exists and the process is trusted.
    private func attemptCreateTap() {
        guard tap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

                switch type {
                case .keyDown, .keyUp:
                    let isDown = (type == .keyDown)

                    // Track currently-pressed keys ourselves so we know the real
                    // state of the space key (rather than relying on a modifier
                    // flag, which doesn't reliably reflect the plain space key).
                    if isDown {
                        mgr.pressedKeys.insert(code)
                    } else {
                        mgr.pressedKeys.remove(code)
                    }
                    // Gate the space→lock behaviour behind the opt-in flag: when
                    // disabled, `spaceDown` is forced false so a spacebar press
                    // during recording is IGNORED (never locks the session).
                    let spacePressed = mgr.pressedKeys.contains(mgr.spaceKey)
                    let spaceDown = mgr.handsFreeLockEnabled && spacePressed
                    if code == mgr.spaceKey, isDown, mgr.machine.isRecording {
                        if mgr.handsFreeLockEnabled {
                            AppLog.log("[Lotti] hands-free lock: applying lock (key + space while recording)")
                        } else {
                            AppLog.log("[Lotti] hands-free lock: ignored space press (feature off)")
                        }
                    }

                    if let ev = mgr.machine.handle(keyCode: code, isDown: isDown, spaceDown: spaceDown) {
                        print("[Lotti] hotkey \(ev) key=0x\(String(code, radix: 16))")
                        AppLog.log("Hotkey event \(ev) (triggerKey=\(mgr.machine.triggerKey))")
                        DispatchQueue.main.async { mgr.onEvent?(ev) }
                    }

                case .flagsChanged:
                    // Modifier keys (⌘ ⌥ ⌃ ⇧ Fn) never emit keyDown/keyUp — only
                    // flagsChanged. Map the keycode to its flag bit and use our
                    // own pressed-set to determine a reliable press/release
                    // transition (left+right share one flag, e.g. both ⌘ keys
                    // set .maskCommand).
                    let flag: CGEventFlags?
                    switch code {
                    case 0x37, 0x36: flag = .maskCommand
                    case 0x38, 0x3C: flag = .maskShift
                    case 0x3A, 0x3D: flag = .maskAlternate
                    case 0x3B, 0x3E: flag = .maskControl
                    case 0x3F: flag = .maskSecondaryFn
                    default: flag = nil
                    }

                    if let flag {
                        let flagPresent = event.flags.contains(flag)
                        let wasPressed = mgr.pressedKeys.contains(code)
                        let isDown: Bool
                        if !wasPressed && flagPresent {
                            isDown = true
                            mgr.pressedKeys.insert(code)
                        } else if wasPressed && !flagPresent {
                            isDown = false
                            mgr.pressedKeys.remove(code)
                        } else {
                            // No real transition for this specific keycode
                            // (e.g. the other ⌘ key toggled the shared flag).
                            return Unmanaged.passUnretained(event)
                        }
                        // Space is a regular key (handled above), never a
                        // modifier — but keep the same gate here for safety.
                        let spaceDown = mgr.handsFreeLockEnabled && mgr.pressedKeys.contains(mgr.spaceKey)

                        if let ev = mgr.machine.handle(keyCode: code, isDown: isDown, spaceDown: spaceDown) {
                            print("[Lotti] hotkey \(ev) key=0x\(String(code, radix: 16))")
                            AppLog.log("Hotkey event \(ev) (triggerKey=\(mgr.machine.triggerKey))")
                            DispatchQueue.main.async { mgr.onEvent?(ev) }
                        }
                    }

                default:
                    break
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())

        guard let created else { return }
        tap = created
        let src = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        runLoopSource = src
        isActive = true
        AppLog.log("Hotkey tap created — global push-to-talk is LIVE")

        // Tap is up and trust is granted: tear down the retry machinery.
        if AXIsProcessTrusted() {
            retryTimer?.invalidate(); retryTimer = nil
            NotificationCenter.default.removeObserver(
                self, name: NSApplication.didBecomeActiveNotification, object: nil)
        }
    }
}
