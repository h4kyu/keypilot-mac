import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let permissionManager = PermissionManager()
    private var eventTapManager: EventTapManager?

    private var statusLineItem: NSMenuItem?
    private var resumeItem: NSMenuItem?
    private var learnedShortcutsController: LearnedShortcutsWindowController?
    private var preferencesController: PreferencesWindowController?

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
        menu.delegate = self
        menu.autoenablesItems = false

        let status = NSMenuItem(title: "Keypilot: On", action: nil, keyEquivalent: "")
        menu.addItem(status)
        statusLineItem = status

        menu.addItem(.separator())

        let snoozeRoot = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
        let snoozeSub = NSMenu()
        snoozeSub.addItem(withTitle: SnoozeDuration.oneHour.label,  action: #selector(snoozeOneHour),  keyEquivalent: "")
        snoozeSub.addItem(withTitle: SnoozeDuration.today.label,    action: #selector(snoozeToday),    keyEquivalent: "")
        snoozeSub.addItem(withTitle: SnoozeDuration.thisWeek.label, action: #selector(snoozeThisWeek), keyEquivalent: "")
        snoozeRoot.submenu = snoozeSub
        menu.addItem(snoozeRoot)

        let resume = NSMenuItem(title: "Resume coaching", action: #selector(resumeCoaching), keyEquivalent: "")
        menu.addItem(resume)
        resumeItem = resume

        menu.addItem(.separator())
        menu.addItem(withTitle: "Learned Shortcuts…", action: #selector(openLearnedShortcuts), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(withTitle: "Open Log…", action: #selector(openLog), keyEquivalent: "")
        menu.addItem(withTitle: "Permissions…", action: #selector(openPermissions), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let until = SnoozeManager.shared.globalSnoozedUntil, Date() < until {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            fmt.dateStyle = .none
            statusLineItem?.title = "Keypilot: Snoozed until \(fmt.string(from: until))"
            resumeItem?.isEnabled = true
        } else {
            statusLineItem?.title = "Keypilot: On"
            resumeItem?.isEnabled = false
        }
    }

    // MARK: - Observers

    private func startObservers() {
        SemanticLogger.shared.log("Permissions granted — starting observers")

        eventTapManager = EventTapManager()
        eventTapManager?.start()
    }

    // MARK: - Menu actions

    @objc private func openLearnedShortcuts() {
        if learnedShortcutsController == nil {
            learnedShortcutsController = LearnedShortcutsWindowController()
        }
        learnedShortcutsController?.present()
    }

    @objc private func openSettings() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        preferencesController?.present()
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(SemanticLogger.shared.logFileURL)
    }

    @objc private func openPermissions() {
        permissionManager.openAccessibilityPreferences()
    }

    @objc private func snoozeOneHour()  { SnoozeManager.shared.snoozeFor(.oneHour) }
    @objc private func snoozeToday()    { SnoozeManager.shared.snoozeFor(.today) }
    @objc private func snoozeThisWeek() { SnoozeManager.shared.snoozeFor(.thisWeek) }
    @objc private func resumeCoaching() { SnoozeManager.shared.unsnooze() }
}
