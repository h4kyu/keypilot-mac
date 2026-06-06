import SwiftUI

struct LearnedShortcutsView: View {
    @ObservedObject private var store = BehaviorStore.shared

    private var learned: [BehaviorRecord] {
        store.allRecords.filter { $0.state == .learned }
    }

    var body: some View {
        Group {
            if learned.isEmpty {
                VStack {
                    Spacer()
                    Text("No shortcuts learned yet.")
                        .foregroundStyle(.secondary)
                    Text("Use a shortcut three times to retire its hint.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(learned) {
                    TableColumn("Shortcut") { rec in
                        Text(rec.shortcut).font(.system(.body, design: .monospaced))
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Title") { rec in
                        Text(displayTitle(rec))
                    }

                    TableColumn("App") { rec in
                        Text(appName(rec.bundleID))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 120, ideal: 160)
                }
            }
        }
        .padding()
    }

    private func displayTitle(_ rec: BehaviorRecord) -> String {
        if !rec.menuTitle.isEmpty { return rec.menuTitle }
        return ShortcutResolver.titleForShortcut(rec.shortcut) ?? "—"
    }

    private func appName(_ bundleID: String) -> String {
        bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}
