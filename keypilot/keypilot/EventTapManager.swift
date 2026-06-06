import AppKit
import ApplicationServices
import CoreGraphics

final class EventTapManager {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            SemanticLogger.shared.log("EventTap failed — grant Input Monitoring in System Settings")
            return
        }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        runLoopSource = src
        SemanticLogger.shared.log("EventTap started (listen-only)")
    }

    fileprivate func reEnable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        SemanticLogger.shared.log("EventTap re-enabled after timeout")
    }

    fileprivate func handleKeyDown(_ event: CGEvent) {
        let flags = event.flags
        guard flags.contains(.maskCommand) else { return }
        guard let shortcut = ShortcutResolver.format(cgFlags: flags, char: Self.character(from: event)) else { return }

        KeyboardSuppressor.shared.recordShortcut(shortcut)

        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        guard !AppExclusionStore.shared.isExcluded(bundleID) else { return }
        BehaviorStore.shared.recordKeyboardInvocation(bundleID: bundleID, shortcut: shortcut)
    }

    fileprivate func handleMouseUp(_ event: CGEvent) {
        let pos = event.location
        let sysWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(sysWide, Float(pos.x), Float(pos.y), &elementRef) == .success,
              let element = elementRef else { return }

        var roleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        guard let role = roleRef as? String, role == (kAXMenuItemRole as String) else { return }

        // AXUIElementGetPid is more reliable than frontmostApplication here — the
        // frontmost app is racy while a status menu is open.
        var ownerPID: pid_t = 0
        AXUIElementGetPid(element, &ownerPID)
        if ownerPID == getpid() { return }

        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? ""

        var cmdCharRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)
        let cmdChar = (cmdCharRef as? String) ?? ""

        var cmdModRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &cmdModRef)
        let modifiers = (cmdModRef as? Int) ?? 0

        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        guard !AppExclusionStore.shared.isExcluded(bundleID) else { return }

        guard let action = ShortcutResolver.resolve(
            cmdChar: cmdChar, modifiers: modifiers, bundleID: bundleID, menuTitle: title
        ) else {
            if !title.isEmpty {
                SemanticLogger.shared.log("Click: \"\(title)\" (no shortcut)")
            }
            return
        }

        if KeyboardSuppressor.shared.shouldSuppress(action.shortcut) {
            SemanticLogger.shared.log("Suppressed (recent keypress): \"\(title)\" → \(action.shortcut)")
            return
        }

        if SnoozeManager.shared.isSnoozed {
            SemanticLogger.shared.log("Snoozed: \"\(title)\" → \(action.shortcut)")
            return
        }

        let shouldShow = BehaviorStore.shared.recordMouseInvocation(
            bundleID: bundleID, shortcut: action.shortcut, menuTitle: title
        )
        if shouldShow {
            SemanticLogger.shared.log("Coach: \"\(title)\" → \(action.shortcut) [\(bundleID)]")
            OverlayPanel.shared.show(action: action)
        } else {
            SemanticLogger.shared.log("Tracked: \"\(title)\" → \(action.shortcut) [\(bundleID)]")
        }
    }

    private static func character(from event: CGEvent) -> String {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4,
                                       actualStringLength: &length,
                                       unicodeString: &chars)
        return String(utf16CodeUnits: chars, count: length)
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let mgr = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    switch type {
    case .keyDown:                  mgr.handleKeyDown(event)
    case .leftMouseUp:              mgr.handleMouseUp(event)
    case .tapDisabledByTimeout,
         .tapDisabledByUserInput:   mgr.reEnable()
    default:                        break
    }
    return Unmanaged.passUnretained(event)
}
