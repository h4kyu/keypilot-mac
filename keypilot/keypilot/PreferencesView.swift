import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            LearnedShortcutsView()
                .tabItem { Label("Learned Shortcuts", systemImage: "checkmark.seal") }
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}
