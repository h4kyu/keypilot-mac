import AppKit
import ApplicationServices

// Attaches an AXObserver to the frontmost app and listens for menu item
// selections. On each selection it resolves the shortcut and shows the overlay.
final class AXObserverManager {
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var workspaceToken: Any?

    func start() {
        if let app = NSWorkspace.shared.frontmostApplication {
            attach(to: app)
        }
        workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            self?.attach(to: app)
        }
    }

    // MARK: - Attach / detach

    private func attach(to app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid != observedPID else { return }
        detach()

        var obs: AXObserver?
        guard AXObserverCreate(pid, axCallback, &obs) == .success, let obs else { return }

        let appEl = AXUIElementCreateApplication(pid)
        let note = kAXMenuItemSelectedNotification as CFString

        // Adding the notification to the app element causes it to fire for
        // any menu item selected in that process.
        guard AXObserverAddNotification(obs, appEl, note,
                                        Unmanaged.passUnretained(self).toOpaque()) == .success
        else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        observer = obs
        observedPID = pid
        SemanticLogger.shared.log("AXObserver → \(app.localizedName ?? "pid:\(pid)")")
    }

    private func detach() {
        guard let obs = observer, observedPID != 0 else { return }
        let appEl = AXUIElementCreateApplication(observedPID)
        AXObserverRemoveNotification(obs, appEl, kAXMenuItemSelectedNotification as CFString)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        observer = nil
        observedPID = 0
    }

    // MARK: - Notification handler

    fileprivate func handleMenuItemSelected(_ element: AXUIElement) {
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? ""

        var cmdCharRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)
        let cmdChar = cmdCharRef as? String ?? ""

        var cmdModRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModRef)
        let modifiers = (cmdModRef as? Int) ?? 0

        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""

        guard let action = ShortcutResolver.resolve(
            cmdChar: cmdChar, modifiers: modifiers,
            bundleID: bundleID, menuTitle: title
        ) else {
            if !title.isEmpty {
                SemanticLogger.shared.log("Menu: \"\(title)\" (no shortcut)")
            }
            return
        }

        SemanticLogger.shared.log("Menu: \"\(title)\" → \(action.shortcut) [\(bundleID)]")
        OverlayPanel.shared.show(action: action)
    }
}

// C callback — bridges back to the Swift instance via refcon.
private func axCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let mgr = Unmanaged<AXObserverManager>.fromOpaque(refcon).takeUnretainedValue()
    if notification as String == kAXMenuItemSelectedNotification as String {
        mgr.handleMenuItemSelected(element)
    }
}
