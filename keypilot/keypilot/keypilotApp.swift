import SwiftUI

@main
struct keypilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement app — no window. Settings scene suppresses SwiftUI's
        // automatic window creation without appearing on its own.
        Settings { EmptyView() }
    }
}
