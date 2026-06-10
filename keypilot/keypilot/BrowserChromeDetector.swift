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

    private func isAddressBar(element: AXUIElement, role: String) -> Bool {
        if role == "AXTextField" || role == "AXComboBox" {
            return isOutsideWebContent(element)
        }
        // Chromium exposes the address bar as an AXGroup wrapping the actual text field.
        if role == "AXGroup" {
            return isOutsideWebContent(element) && hasTextInputChild(element)
        }
        return false
    }

    private func hasTextInputChild(_ element: AXUIElement) -> Bool {
        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return false }
        return children.contains { child in
            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let r = (roleRef as? String) ?? ""
            return r == "AXTextField" || r == "AXComboBox"
        }
    }

    // Walk up the parent chain. Web page content (Google search box, form inputs,
    // etc.) always lives under AXWebArea. The browser address bar never does.
    // Chromium browsers don't expose AXToolbar, so checking for AXWebArea absence
    // is the universal signal that works across Safari, Chrome, Edge, Brave, Arc.
    private func isOutsideWebContent(_ element: AXUIElement) -> Bool {
        var current = element
        for _ in 0..<20 {
            var parentRef: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef else { return true }
            let parentEl = parent as! AXUIElement

            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(parentEl, kAXRoleAttribute as CFString, &roleRef)
            let parentRole = (roleRef as? String) ?? ""

            if parentRole == "AXWebArea"                       { return false }
            if parentRole == "AXWindow" || parentRole == "AXApplication" { return true }

            current = parentEl
        }
        return true
    }
}
