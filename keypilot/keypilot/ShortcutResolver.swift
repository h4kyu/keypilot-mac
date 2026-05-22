import Foundation

struct SemanticAction {
    let menuTitle: String   // e.g. "Copy"
    let shortcut: String    // e.g. "⌘C"
    let bundleID: String
}

enum ShortcutResolver {
    // kAXMenuItemCmdModifiers values (Carbon HI Toolbox bitmask):
    //   0 = ⌘ only   1 = ⇧   2 = ⌥   4 = ⌃   8 = no ⌘ (function key)
    static func resolve(cmdChar: String, modifiers: Int, bundleID: String, menuTitle: String) -> SemanticAction? {
        guard !cmdChar.isEmpty, modifiers & 8 == 0 else { return nil }

        var prefix = ""
        if modifiers & 4 != 0 { prefix += "⌃" }
        if modifiers & 2 != 0 { prefix += "⌥" }
        if modifiers & 1 != 0 { prefix += "⇧" }

        let shortcut = prefix + "⌘" + cmdChar.uppercased()
        return SemanticAction(menuTitle: menuTitle, shortcut: shortcut, bundleID: bundleID)
    }
}
