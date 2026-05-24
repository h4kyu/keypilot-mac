import AppKit
import ApplicationServices

// Attaches an AXObserver to the frontmost app and listens for menu item
// selections. On each selection it resolves the shortcut and shows the overlay.
final class AXObserverManager {
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var observedElements: [AXUIElement] = []
    private var workspaceToken: Any?

    // Last item highlighted via SelectedChildrenChanged. If a menu closes
    // soon after the highlight, we treat the highlight as a click — AppKit
    // doesn't post MenuItemSelected for mouse-driven menu invocations.
    private var lastHighlightedItem: AXUIElement?
    private var lastHighlightedAt: Date?

    // AXUIElement is a CFType; direct `as? [AXUIElement]` casts on the
    // CFTypeRef returned by AXUIElementCopyAttributeValue are unreliable
    // across macOS versions. Bridging through [AnyObject] and casting
    // each element is the pattern AXSwift and other AX wrappers use.
    private static func axChildren(of element: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref) == .success,
              let array = ref as? [AnyObject] else { return [] }
        return array.map { $0 as! AXUIElement }
    }

    // For diagnostics: "AXMenuBarItem/'Edit'". Reads role + title.
    fileprivate static func describe(_ element: AXUIElement) -> String {
        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let role = (roleRef as? String) ?? "?"
        let title = (titleRef as? String) ?? ""
        return "\(role)/'\(title)'"
    }

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
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var registered: [AXUIElement] = []

        // (a) App element catches AppKit's shortcut-dispatched MenuItemSelected
        // (⌘C and friends). The notification is posted here and does not
        // propagate down into the menu hierarchy.
        if AXObserverAddNotification(obs, appEl, note, refcon) == .success {
            registered.append(appEl)
        }

        // (b) Each AXMenu catches mouse-click MenuItemSelected. The notification
        // fires on the clicked AXMenuItem and propagates exactly one level up —
        // to its containing AXMenu — but no further. The hierarchy is:
        //   AXApplication > AXMenuBar > AXMenuBarItem > AXMenu > AXMenuItem
        // so we have to descend two levels from the menu bar before registering.
        var menuBarRef: CFTypeRef?
        let mbResult = AXUIElementCopyAttributeValue(appEl, kAXMenuBarAttribute as CFString, &menuBarRef)
        // Also try MenuOpened on the app element itself.
        if AXObserverAddNotification(obs, appEl, kAXMenuOpenedNotification as CFString, refcon) == .success {
            registered.append(appEl)
        }

        if mbResult == .success, let menuBarValue = menuBarRef {
            let menuBarEl = menuBarValue as! AXUIElement
            // Discovery: register MenuOpened and SelectedChildrenChanged at
            // every plausible level so the [AX] diagnostic line in the callback
            // tells us which fires. Once we know, we can drop the others.
            let menuBarItems = Self.axChildren(of: menuBarEl)
            let openedNote = kAXMenuOpenedNotification as CFString
            let closedNote = kAXMenuClosedNotification as CFString
            let selChildNote = kAXSelectedChildrenChangedNotification as CFString
            let beforeOpenRegs = registered.count
            // Level: menu bar itself
            if AXObserverAddNotification(obs, menuBarEl, openedNote, refcon) == .success {
                registered.append(menuBarEl)
            }
            if AXObserverAddNotification(obs, menuBarEl, selChildNote, refcon) == .success {
                registered.append(menuBarEl)
            }
            for item in menuBarItems {
                // Level: each AXMenu (the dropdown under a bar item). AXMenu
                // accepts MenuOpened, MenuClosed, and SelectedChildrenChanged.
                for menu in Self.axChildren(of: item) {
                    if AXObserverAddNotification(obs, menu, openedNote, refcon) == .success {
                        registered.append(menu)
                    }
                    if AXObserverAddNotification(obs, menu, closedNote, refcon) == .success {
                        registered.append(menu)
                    }
                    if AXObserverAddNotification(obs, menu, selChildNote, refcon) == .success {
                        registered.append(menu)
                    }
                }
            }
            SemanticLogger.shared.log("AXObserver: \(menuBarItems.count) menu bar items → \(registered.count - beforeOpenRegs) discovery watchers")
        } else {
            SemanticLogger.shared.log("AXObserver: no menu bar for \(app.localizedName ?? "pid:\(pid)")")
        }

        guard !registered.isEmpty else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        observer = obs
        observedPID = pid
        observedElements = registered
        SemanticLogger.shared.log("AXObserver → \(app.localizedName ?? "pid:\(pid)") (\(registered.count) total)")
    }

    private func detach() {
        guard let obs = observer, observedPID != 0 else { return }
        let notes = [
            kAXMenuItemSelectedNotification as CFString,
            kAXMenuOpenedNotification as CFString,
            kAXMenuClosedNotification as CFString,
            kAXSelectedChildrenChangedNotification as CFString,
        ]
        for el in observedElements {
            for note in notes {
                AXObserverRemoveNotification(obs, el, note)
            }
        }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        observer = nil
        observedPID = 0
        observedElements = []
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

        if KeyboardSuppressor.shared.shouldSuppress(action.shortcut) {
            SemanticLogger.shared.log("Suppressed (keyboard-fired): \"\(title)\" → \(action.shortcut) [\(bundleID)]")
            return
        }

        SemanticLogger.shared.log("Menu: \"\(title)\" → \(action.shortcut) [\(bundleID)]")
        OverlayPanel.shared.show(action: action)
    }

    // AXMenu's children are lazy: they materialize when the menu opens.
    // On every MenuOpened we (re-)register MenuItemSelected on each item and
    // MenuOpened on each sub-menu. Re-registrations return
    // kAXErrorNotificationAlreadyRegistered, which we treat as a no-op.
    fileprivate func handleMenuOpened(_ menu: AXUIElement) {
        guard let obs = observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let selected = kAXMenuItemSelectedNotification as CFString
        let opened = kAXMenuOpenedNotification as CFString

        var newItemRegs = 0
        var newSubMenuRegs = 0
        for item in Self.axChildren(of: menu) {
            if AXObserverAddNotification(obs, item, selected, refcon) == .success {
                observedElements.append(item)
                newItemRegs += 1
            }
            for subMenu in Self.axChildren(of: item) {
                if AXObserverAddNotification(obs, subMenu, opened, refcon) == .success {
                    observedElements.append(subMenu)
                    newSubMenuRegs += 1
                }
            }
        }
        if newItemRegs > 0 || newSubMenuRegs > 0 {
            SemanticLogger.shared.log("MenuOpened → +\(newItemRegs) item watchers, +\(newSubMenuRegs) sub-menu watchers")
        }
    }

    // Reads the menu's currently-highlighted item and caches it. The cache
    // is consulted on MenuClosed to decide whether a click happened.
    fileprivate func handleSelectedChildrenChanged(_ menu: AXUIElement) {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menu, kAXSelectedChildrenAttribute as CFString, &ref) == .success,
              let array = ref as? [AnyObject], !array.isEmpty else { return }
        lastHighlightedItem = (array[0] as! AXUIElement)
        lastHighlightedAt = Date()
    }

    // If the highlight was set very recently (≤150 ms), the close is almost
    // certainly because the user clicked the highlighted item. Outside that
    // window, treat the close as a dismissal and do nothing.
    fileprivate func handleMenuClosed(_ menu: AXUIElement) {
        defer { lastHighlightedItem = nil; lastHighlightedAt = nil }
        guard let item = lastHighlightedItem,
              let at = lastHighlightedAt,
              Date().timeIntervalSince(at) <= 0.15 else { return }
        handleMenuItemSelected(item)
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
    SemanticLogger.shared.log("[AX] \(notification as String) ← \(AXObserverManager.describe(element))")
    switch notification as String {
    case kAXMenuItemSelectedNotification as String:
        mgr.handleMenuItemSelected(element)
    case kAXMenuOpenedNotification as String:
        mgr.handleMenuOpened(element)
    case kAXSelectedChildrenChangedNotification as String:
        mgr.handleSelectedChildrenChanged(element)
    case kAXMenuClosedNotification as String:
        mgr.handleMenuClosed(element)
    default:
        break
    }
}
