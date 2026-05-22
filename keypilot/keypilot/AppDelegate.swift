import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let permissionManager = PermissionManager()
    private var eventTapManager: EventTapManager?
    private var axObserverManager: AXObserverManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusMenu()
        permissionManager.requestIfNeeded { [weak self] in
            self?.startObservers()
        }
    }

    // MARK: - Status item

    private func buildStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keypilot")

        let menu = NSMenu()
        menu.addItem(withTitle: "Keypilot", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Log…", action: #selector(openLog), keyEquivalent: "")
        menu.addItem(withTitle: "Permissions…", action: #selector(openPermissions), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    // MARK: - Observers

    private func startObservers() {
        SemanticLogger.shared.log("Permissions granted — starting observers")

        eventTapManager = EventTapManager()
        axObserverManager = AXObserverManager()

        eventTapManager?.start()
        axObserverManager?.start()
    }

    // MARK: - Menu actions

    @objc private func openLog() {
        NSWorkspace.shared.open(SemanticLogger.shared.logFileURL)
    }

    @objc private func openPermissions() {
        permissionManager.openAccessibilityPreferences()
    }
}
