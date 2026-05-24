import Foundation
import CoreGraphics

struct SemanticAction {
    let menuTitle: String   // e.g. "Copy"
    let shortcut: String    // e.g. "⌘C"
    let bundleID: String
}

enum ShortcutResolver {
    // kAXMenuItemCmdModifiers values (Carbon HI Toolbox bitmask):
    //   0 = ⌘ only   1 = ⇧   2 = ⌥   4 = ⌃   8 = no ⌘ (function key)
    static func resolve(cmdChar: String, modifiers: Int, bundleID: String, menuTitle: String) -> SemanticAction? {
        // Primary: shortcut metadata exposed on the menu item itself.
        if !cmdChar.isEmpty, modifiers & 8 == 0 {
            var prefix = ""
            if modifiers & 4 != 0 { prefix += "⌃" }
            if modifiers & 2 != 0 { prefix += "⌥" }
            if modifiers & 1 != 0 { prefix += "⇧" }
            let shortcut = prefix + "⌘" + cmdChar.uppercased()
            return SemanticAction(menuTitle: menuTitle, shortcut: shortcut, bundleID: bundleID)
        }

        // Fallback: context menus typically don't carry cmdChar even when
        // the same action has a well-known shortcut elsewhere. Look up the
        // v1 universal commands by title.
        if let shortcut = commonShortcutsByTitle[normalize(menuTitle)] {
            return SemanticAction(menuTitle: menuTitle, shortcut: shortcut, bundleID: bundleID)
        }
        return nil
    }

    private static let commonShortcutsByTitle: [String: String] = [
        "Copy": "⌘C",
        "Paste": "⌘V",
        "Cut": "⌘X",
        "Undo": "⌘Z",
        "Redo": "⌘⇧Z",
        "Select All": "⌘A",
        "Save": "⌘S",
        "Find": "⌘F",
        "Open": "⌘O",
        "New": "⌘N",
        "Close": "⌘W",
        "Print": "⌘P",
        "Quit": "⌘Q",
        "Hide": "⌘H",
        "Minimize": "⌘M",
    ]

    // Strip trailing ellipsis ("…" or "...") and surrounding whitespace so
    // "Find…" and "Find" map to the same table entry.
    private static func normalize(_ title: String) -> String {
        var t = title.trimmingCharacters(in: .whitespaces)
        if t.hasSuffix("…") { t = String(t.dropLast()) }
        if t.hasSuffix("...") { t = String(t.dropLast(3)) }
        return t.trimmingCharacters(in: .whitespaces)
    }

    // Mirror of `resolve(...)` for the event-tap side. Returns the same
    // "⌘⇧Z" form so KeyboardSuppressor can string-compare across sources.
    // nil when ⌘ isn't held or the character is empty.
    static func format(cgFlags: CGEventFlags, char: String) -> String? {
        guard cgFlags.contains(.maskCommand), !char.isEmpty else { return nil }

        var prefix = ""
        if cgFlags.contains(.maskControl)   { prefix += "⌃" }
        if cgFlags.contains(.maskAlternate) { prefix += "⌥" }
        if cgFlags.contains(.maskShift)     { prefix += "⇧" }

        return prefix + "⌘" + char.uppercased()
    }
}



