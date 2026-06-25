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

    // Wired up by EventTapManager to feed async tab-close detections into dispatchAction.
    var onDetected: ((SemanticAction) -> Void)?

    func handle(element: AXUIElement, role: String, bundleID: String, clickAt: CGPoint) -> SemanticAction? {
        guard Self.knownBrowsers.contains(bundleID) else { return nil }
        if isNewTabButton(element: element, role: role) {
            return SemanticAction(menuTitle: "New Tab", shortcut: "⌘T", bundleID: bundleID)
        }
        guard isAddressBar(element: element, role: role) else { return nil }
        return SemanticAction(menuTitle: "Address Bar", shortcut: "⌘L", bundleID: bundleID)
    }

    // On mouseDown, AX hit-tests the actual AXButton directly (unlike mouseUp where the tab
    // is already gone). Check the label here and fire immediately — no async counting needed.
    func handleMouseDown(element: AXUIElement, role: String, bundleID: String, clickAt: CGPoint) {
        guard Self.knownBrowsers.contains(bundleID) else { return }
        if role == "AXButton" {
            let label = axLabel(element).lowercased()
            guard isOutsideWebContent(element) else { return }
            if label == "close tab" || label == "close" {
                onDetected?(SemanticAction(menuTitle: "Tab Close", shortcut: "⌘W", bundleID: bundleID))
            } else if Self.reloadButtonLabels.contains(label) {
                onDetected?(SemanticAction(menuTitle: "Reload", shortcut: "⌘R", bundleID: bundleID))
            }
            return
        }
        // Chrome/Chromium: the tab strip returns AXGroup with an empty label. The × button
        // is always within the rightmost ~40px of the frame — clicking elsewhere in the strip
        // (to switch tabs) lands toward the center, so the right-edge threshold is reliable.
        if role == "AXGroup" && axLabel(element).isEmpty && isOutsideWebContent(element) && !hasTextInputChild(element) {
            if let frame = axFrame(element), frame.contains(clickAt), frame.maxX - clickAt.x <= 40 {
                onDetected?(SemanticAction(menuTitle: "Tab Close", shortcut: "⌘W", bundleID: bundleID))
            }
        }
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
        "New Tab",          // Safari, Chrome, Edge, Brave
        "Open a new tab",   // Firefox
    ]

    private func isNewTabButton(element: AXUIElement, role: String) -> Bool {
        guard role == "AXButton" else { return false }
        guard isOutsideWebContent(element) else { return false }
        return Self.newTabButtonLabels.contains(axLabel(element))
    }

    private static let reloadButtonLabels: Set<String> = [
        "reload page",          // Chrome, Edge
        "reload this page",     // Safari
        "reload",               // Chrome (older), Brave
        "reload current page",  // Firefox
        "reload tab",           // Firefox alternate
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
