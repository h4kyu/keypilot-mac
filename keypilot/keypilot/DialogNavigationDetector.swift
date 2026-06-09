import AppKit
import ApplicationServices

final class DialogNavigationDetector {
    private static let cancelTitles: Set<String> = ["Cancel", "Don't Save", "Don't Allow", "Deny", "Revert"]
    private static let confirmTitles: Set<String> = ["OK", "Done", "Allow", "Open", "Save", "Apply", "Continue", "Yes", "Install", "Replace"]

    // Tracks the last hint shown so Esc/Return keypresses can retire it.
    private var lastCoached: (bundleID: String, shortcut: String, at: Date)?
    // Adoption is only credited within this window after a hint.
    private let adoptionWindow: TimeInterval = 10.0

    func handle(element: AXUIElement, role: String, bundleID: String) -> SemanticAction? {
        guard role == kAXButtonRole as String else { return nil }
        guard isInAlertOrSheet(element: element) else { return nil }

        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? ""

        if Self.cancelTitles.contains(title) {
            return SemanticAction(menuTitle: "Cancel", shortcut: "Esc", bundleID: bundleID)
        }
        // Coach Return for the default button or any known confirm title.
        if isDefaultButton(element) || Self.confirmTitles.contains(title) {
            let label = title.isEmpty ? "Confirm" : title
            return SemanticAction(menuTitle: label, shortcut: "Return", bundleID: bundleID)
        }
        return nil
    }

    func recordCoached(bundleID: String, shortcut: String) {
        lastCoached = (bundleID: bundleID, shortcut: shortcut, at: Date())
    }

    // Called by EventTapManager on every Esc/Return keypress.
    func recordAdoptionIfPending(shortcut: String, bundleID: String) {
        guard let hint = lastCoached,
              hint.shortcut == shortcut,
              hint.bundleID == bundleID,
              Date().timeIntervalSince(hint.at) < adoptionWindow else { return }
        lastCoached = nil
        BehaviorStore.shared.recordKeyboardInvocation(bundleID: bundleID, shortcut: shortcut)
    }

    private func isInAlertOrSheet(element: AXUIElement) -> Bool {
        var current: AXUIElement = element
        for _ in 0..<4 {
            var parentRef: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef else { return false }
            // Safe cast: AX attribute values returned for kAXParentAttribute are always AXUIElements.
            let parentEl = parent as! AXUIElement

            var roleRef: AnyObject?
            AXUIElementCopyAttributeValue(parentEl, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            if role == "AXSheet" { return true }

            var subroleRef: AnyObject?
            AXUIElementCopyAttributeValue(parentEl, kAXSubroleAttribute as CFString, &subroleRef)
            if (subroleRef as? String) == "AXDialog" { return true }

            current = parentEl
        }
        return false
    }

    private func isDefaultButton(_ element: AXUIElement) -> Bool {
        var subroleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
        return (subroleRef as? String) == "AXDefaultButton"
    }
}
