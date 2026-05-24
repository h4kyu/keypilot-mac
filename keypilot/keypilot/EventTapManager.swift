import AppKit
import ApplicationServices
import CoreGraphics

// Listens for keyboard events (shortcut adoption) and mouse-up events
// (UI hit-testing). Uses a listen-only tap so it never blocks or modifies.
final class EventTapManager {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            SemanticLogger.shared.log("EventTap failed — grant Input Monitoring in System Settings")
            return
        }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        runLoopSource = src
        SemanticLogger.shared.log("EventTap started (listen-only)")
    }

    fileprivate func handleKeyDown(_ event: CGEvent) {
        let flags = event.flags
        guard flags.contains(.maskCommand) else { return }

        // Record for suppression. Done before adoption logging so it covers
        // every ⌘-modified shortcut, not just the v1 adoption table below.
        if let shortcut = ShortcutResolver.format(cgFlags: flags, char: Self.character(from: event)) {
            KeyboardSuppressor.shared.recordShortcut(shortcut)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // v1 shortcut detection table (key codes for ⌘ + letter)
        let adoptions: [Int64: String] = [
            8: "copy",      // C
            9: "paste",     // V
            7: "cut",       // X
            6: "undo",      // Z
            3: "find",      // F
            1: "save",      // S
            0: "selectAll", // A
            13: "new",      // N
            12: "quit",     // Q
        ]

        if let action = adoptions[keyCode] {
            let hasShift = flags.contains(.maskShift)
            let label = hasShift && action == "undo" ? "redo" : action
            SemanticLogger.shared.log("Shortcut adopted: \(label)")
        }
    }
}

// C function bridging to the class instance
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown, let refcon else { return Unmanaged.passUnretained(event) }
    let mgr = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    mgr.handleKeyDown(event)
    return Unmanaged.passUnretained(event)
}
