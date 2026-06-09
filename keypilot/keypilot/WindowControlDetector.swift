import AppKit
import ApplicationServices

final class WindowControlDetector {
    func handle(element: AXUIElement, role: String, bundleID: String) -> SemanticAction? {
        switch role {
        case "AXCloseButton":
            return SemanticAction(menuTitle: "Close Window", shortcut: "⌘W", bundleID: bundleID)
        case "AXMinimizeButton":
            return SemanticAction(menuTitle: "Minimize Window", shortcut: "⌘M", bundleID: bundleID)
        default:
            return nil
        }
    }
}
