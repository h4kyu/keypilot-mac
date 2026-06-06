import AppKit
import SwiftUI

final class LearnedShortcutsWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let host = NSHostingController(rootView: LearnedShortcutsView())
        let window = NSWindow(contentViewController: host)
        window.title = "Learned Shortcuts"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 520, height: 360))
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
    }

    func present() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
