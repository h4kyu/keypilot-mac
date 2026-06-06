import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let host = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: host)
        window.title = "Keypilot Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 560, height: 400))
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
