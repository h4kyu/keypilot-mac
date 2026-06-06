import Foundation

// When a shortcut fires its menu item, AX posts kAXMenuItemSelectedNotification —
// indistinguishable from a mouse click. This records the keypress so the AX
// observer can skip the redundant notification within the suppression window.
final class KeyboardSuppressor {
    static let shared = KeyboardSuppressor()
    private init() {}

    private var lastShortcut: String?
    private var lastAt: Date?

    // 150 ms: long enough for AX to lag a frame or two after dispatch, short
    // enough that a deliberate mouse click after the shortcut isn't swallowed.
    private let window: TimeInterval = 0.15

    func recordShortcut(_ display: String) {
        lastShortcut = display
        lastAt = Date()
    }

    func shouldSuppress(_ display: String) -> Bool {
        guard let last = lastShortcut, let at = lastAt else { return false }
        guard Date().timeIntervalSince(at) <= window else { return false }
        return last == display
    }
}
