import Foundation

// Coordinates between EventTapManager and AXObserverManager.
//
// When the user presses ⌘C, AppKit dispatches the shortcut by firing the
// Edit → Copy menu item, which causes AX to post kAXMenuItemSelectedNotification.
// That looks identical to the user clicking the menu — so without this
// coordinator, every shortcut press would also trigger a coaching overlay.
//
// The event tap records each ⌘-modified key down; the AX observer checks
// here before showing a hint and skips it if a matching keyboard press
// landed within the window.
final class KeyboardSuppressor {
    static let shared = KeyboardSuppressor()
    private init() {}

    private var lastShortcut: String?
    private var lastAt: Date?

    // 150 ms: AppKit's menu dispatch from a shortcut is effectively
    // instant, but AX notifications can lag a frame or two. Short enough
    // that a deliberate mouse click following the shortcut isn't swallowed.
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
