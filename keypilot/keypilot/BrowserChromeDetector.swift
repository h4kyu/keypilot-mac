import AppKit
import ApplicationServices

final class BrowserChromeDetector {
    private static let knownBrowsers: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",   // Arc
        "org.mozilla.firefox",
    ]

    func handle(element: AXUIElement, role: String, bundleID: String) -> SemanticAction? {
        guard Self.knownBrowsers.contains(bundleID) else { return nil }
        guard isAddressBar(element: element, role: role) else { return nil }
        return SemanticAction(menuTitle: "Address Bar", shortcut: "⌘L", bundleID: bundleID)
    }

    // An address bar is a text/combo field that lives inside an AXToolbar.
    // Web page text fields are never inside the browser toolbar, so this
    // distinguishes the address bar without relying on locale-dependent labels.
    private func isAddressBar(element: AXUIElement, role: String) -> Bool {
        guard role == "AXTextField" || role == "AXComboBox" else { return false }
        return hasToolbarAncestor(element)
    }

    private func hasToolbarAncestor(_ element: AXUIElement) -> Bool {
        var current = element
        for _ in 0..<7 {
            var parentRef: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef else { return false }
            let parentEl = parent as! AXUIElement

            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(parentEl, kAXRoleAttribute as CFString, &roleRef)
            let parentRole = (roleRef as? String) ?? ""

            if parentRole == "AXToolbar" { return true }
            // The address bar won't be deeper than the window — stop searching.
            if parentRole == "AXWindow" { return false }

            current = parentEl
        }
        return false
    }
}
