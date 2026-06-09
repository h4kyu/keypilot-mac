import AppKit
import ApplicationServices

final class DockAndAppSwitchDetector {
    // Use a stable pseudo-bundle so ⌘Tab learning is global, not per-app.
    static let dockBundleID = "com.apple.dock"

    func handle(element: AXUIElement, role: String) -> SemanticAction? {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        guard let app = NSRunningApplication(processIdentifier: pid),
              app.bundleIdentifier == Self.dockBundleID else { return nil }

        // Only coach on clicks on actual Dock items, not the Dock's own menu bar.
        guard role == "AXDockItem" else { return nil }

        return SemanticAction(menuTitle: "Switch Apps", shortcut: "⌘Tab", bundleID: Self.dockBundleID)
    }
}
