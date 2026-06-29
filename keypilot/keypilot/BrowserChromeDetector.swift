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

    var onDetected: ((SemanticAction) -> Void)?

    func handle(element: AXUIElement, role: String, bundleID: String, clickAt: CGPoint) -> SemanticAction? {
        guard Self.knownBrowsers.contains(bundleID) else { return nil }
        if isNewTabButton(element: element, role: role) {
            return SemanticAction(menuTitle: "New Tab", shortcut: "⌘T", bundleID: bundleID)
        }
        if let navAction = navigationButtonAction(element: element, role: role, bundleID: bundleID) {
            return navAction
        }
        guard isAddressBar(element: element, role: role) else { return nil }
        return SemanticAction(menuTitle: "Address Bar", shortcut: "⌘L", bundleID: bundleID)
    }

    // Disabled button means no history; coaching ⌘[/⌘] there would be wrong.
    private func navigationButtonAction(element: AXUIElement, role: String, bundleID: String) -> SemanticAction? {
        guard role == "AXButton", isOutsideWebContent(element), isEnabled(element) else { return nil }
        let label = axLabel(element).lowercased()
        if Self.backButtonLabels.contains(label) {
            return SemanticAction(menuTitle: "Back", shortcut: "⌘[", bundleID: bundleID)
        }
        if Self.forwardButtonLabels.contains(label) {
            return SemanticAction(menuTitle: "Forward", shortcut: "⌘]", bundleID: bundleID)
        }
        return nil
    }

    // Tab close needs mouseDown: the AX element for the tab is gone before mouseUp.
    func handleMouseDown(element: AXUIElement, role: String, bundleID: String, clickAt: CGPoint) {
        guard Self.knownBrowsers.contains(bundleID) else { return }
        SemanticLogger.shared.log("BrowserDown: role=\(role) label=\"\(axLabel(element))\" bundleID=\(bundleID)")
        if role == "AXButton" {
            let label = axLabel(element).lowercased()
            guard isOutsideWebContent(element) else { return }
            if label == "close tab" || label == "close" {
                onDetected?(SemanticAction(menuTitle: "Tab Close", shortcut: "⌘W", bundleID: bundleID))
            } else if Self.reloadButtonLabels.contains(label) {
                onDetected?(SemanticAction(menuTitle: "Reload", shortcut: "⌘R", bundleID: bundleID))
            } else {
                SemanticLogger.shared.log("BrowserButton[\(bundleID)]: \"\(label)\"")
            }
            return
        }
        // Chrome tab strip is AXGroup with empty label; × is always in the rightmost ~40px.
        if role == "AXGroup" && axLabel(element).isEmpty && isOutsideWebContent(element) && !hasTextInputChild(element) {
            if let frame = axFrame(element), frame.contains(clickAt), frame.maxX - clickAt.x <= 40 {
                onDetected?(SemanticAction(menuTitle: "Tab Close", shortcut: "⌘W", bundleID: bundleID))
            }
        }
    }

    private func isEnabled(_ element: AXUIElement) -> Bool {
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &ref) == .success,
              let b = ref as? Bool else { return true }
        return b
    }

    private func axFrame(_ element: AXUIElement) -> CGRect? {
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &ref) == .success,
              ref != nil else { return nil }
        let axVal = ref as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(axVal, .cgRect, &rect) else { return nil }
        return rect
    }

    private static let newTabButtonLabels: Set<String> = [
        "New Tab",
        "Open a new tab",
    ]

    private func isNewTabButton(element: AXUIElement, role: String) -> Bool {
        guard role == "AXButton" else { return false }
        guard isOutsideWebContent(element) else { return false }
        return Self.newTabButtonLabels.contains(axLabel(element))
    }

    private static let reloadButtonLabels: Set<String> = [
        "reload page",
        "reload this page",
        "reload",
        "reload current page",
        "reload tab",
    ]

    private static let backButtonLabels: Set<String> = [
        "back",
        "go back",
        "go back one page",
    ]

    private static let forwardButtonLabels: Set<String> = [
        "forward",
        "go forward",
        "go forward one page",
    ]

    // Reads title then description — browsers vary on which attribute carries the button label.
    private func axLabel(_ element: AXUIElement) -> String {
        var ref: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &ref) == .success,
           let s = ref as? String, !s.isEmpty { return s }
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &ref)
        return (ref as? String) ?? ""
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

    // AXWebArea is the universal boundary: browser chrome never lives under it, web content always does.
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
