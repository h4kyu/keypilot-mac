import Foundation
import CoreGraphics

struct SemanticAction {
    let menuTitle: String
    let shortcut: String
    let bundleID: String
}

enum ShortcutResolver {
    // kAXMenuItemCmdModifiers bitmask: 0=⌘ only, 1=⇧, 2=⌥, 4=⌃, 8=no ⌘ (fn key)
    static func resolve(cmdChar: String, modifiers: Int, bundleID: String, menuTitle: String) -> SemanticAction? {
        if !cmdChar.isEmpty, modifiers & 8 == 0 {
            var prefix = ""
            if modifiers & 4 != 0 { prefix += "⌃" }
            if modifiers & 2 != 0 { prefix += "⌥" }
            if modifiers & 1 != 0 { prefix += "⇧" }
            let shortcut = prefix + "⌘" + cmdChar.uppercased()
            return SemanticAction(menuTitle: menuTitle, shortcut: shortcut, bundleID: bundleID)
        }

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
        "Preferences": "⌘,",
        "Settings": "⌘,",
    ]

    static func titleForShortcut(_ shortcut: String) -> String? {
        for (title, sc) in commonShortcutsByTitle where sc == shortcut {
            return title
        }
        return nil
    }

    private static func normalize(_ title: String) -> String {
        var t = title.trimmingCharacters(in: .whitespaces)
        if t.hasSuffix("…") { t = String(t.dropLast()) }
        if t.hasSuffix("...") { t = String(t.dropLast(3)) }
        return t.trimmingCharacters(in: .whitespaces)
    }

    static func format(cgFlags: CGEventFlags, char: String) -> String? {
        guard cgFlags.contains(.maskCommand), !char.isEmpty else { return nil }

        var prefix = ""
        if cgFlags.contains(.maskControl)   { prefix += "⌃" }
        if cgFlags.contains(.maskAlternate) { prefix += "⌥" }
        if cgFlags.contains(.maskShift)     { prefix += "⇧" }

        return prefix + "⌘" + char.uppercased()
    }
}
