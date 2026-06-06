import AppKit
import ApplicationServices

final class PermissionManager {
    func requestIfNeeded(completion: @escaping () -> Void) {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) {
            completion()
            return
        }
        SemanticLogger.shared.log("Waiting for Accessibility permission…")
        DispatchQueue.global(qos: .utility).async {
            while !AXIsProcessTrusted() {
                Thread.sleep(forTimeInterval: 0.5)
            }
            SemanticLogger.shared.log("Accessibility permission granted")
            DispatchQueue.main.async { completion() }
        }
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
