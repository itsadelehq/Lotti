import AppKit
import CoreGraphics

enum HotkeyEvent { case start, stop, lockToggle, cancel }

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

final class HotkeyManager {
    var onEvent: ((HotkeyEvent) -> Void)?
    let machine = HotkeyStateMachine()
    private var tap: CFMachPort?
    private var pressedKeys = Set<CGKeyCode>()
    private let spaceKey: CGKeyCode = 0x31

    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                let isDown = (type == .keyDown)

                // Track currently-pressed keys ourselves so we know the real
                // state of the space key (rather than relying on a modifier
                // flag, which doesn't reliably reflect the plain space key).
                if isDown {
                    mgr.pressedKeys.insert(code)
                } else {
                    mgr.pressedKeys.remove(code)
                }
                let spaceDown = mgr.pressedKeys.contains(mgr.spaceKey)

                if let ev = mgr.machine.handle(keyCode: code, isDown: isDown, spaceDown: spaceDown) {
                    DispatchQueue.main.async { mgr.onEvent?(ev) }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap {
            let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}
