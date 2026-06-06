import Foundation
import AppKit
import Combine

struct BehaviorRecord: Codable, Identifiable {
    let bundleID: String
    let shortcut: String
    var menuTitle: String
    var mouseCount: Int = 0
    var keyboardCount: Int = 0
    var mouseSinceKeyboard: Int = 0
    var lastShownAt: Date?
    var state: State = .active

    var id: String { "\(bundleID)|\(shortcut)" }

    enum State: String, Codable {
        case active
        case learned
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID, shortcut, menuTitle, mouseCount, keyboardCount,
             mouseSinceKeyboard, lastShownAt, state
    }
}

final class BehaviorStore: ObservableObject {
    static let shared = BehaviorStore()

    @Published private(set) var allRecords: [BehaviorRecord] = []

    private let showAfterMouseCount = 2
    private let cooldownSeconds: TimeInterval = 30
    private let learnedThreshold = 3

    private let url: URL
    private let queue = DispatchQueue(label: "keypilot.behavior-store", qos: .utility)
    private var records: [String: BehaviorRecord] = [:]

    private init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("keypilot", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        url = support.appendingPathComponent("behaviors.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: BehaviorRecord].self, from: data) else {
            return
        }
        records = decoded
        publish()
    }

    private func publish() {
        allRecords = records.values.sorted {
            if $0.bundleID == $1.bundleID { return $0.shortcut < $1.shortcut }
            return $0.bundleID < $1.bundleID
        }
    }

    private func scheduleSave() {
        let snapshot = records
        let dest = url
        queue.async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: dest, options: .atomic)
        }
    }

    private func key(_ bundleID: String, _ shortcut: String) -> String {
        "\(bundleID)|\(shortcut)"
    }

    func recordMouseInvocation(bundleID: String, shortcut: String, menuTitle: String) -> Bool {
        let k = key(bundleID, shortcut)
        var rec = records[k] ?? BehaviorRecord(bundleID: bundleID, shortcut: shortcut, menuTitle: menuTitle)
        rec.menuTitle = menuTitle
        rec.mouseCount += 1
        rec.mouseSinceKeyboard += 1

        if rec.state == .learned && rec.mouseSinceKeyboard >= 3 {
            rec.state = .active
            rec.keyboardCount = 0
            SemanticLogger.shared.log("Regressed: \(shortcut) [\(bundleID)] — resuming coaching")
        }

        let shouldShow: Bool = {
            if rec.state == .learned { return false }
            if let last = rec.lastShownAt, Date().timeIntervalSince(last) < cooldownSeconds { return false }
            return rec.mouseCount >= showAfterMouseCount
        }()

        if shouldShow {
            rec.lastShownAt = Date()
        }
        records[k] = rec
        publish()
        scheduleSave()
        return shouldShow
    }

    func learnedRecords() -> [BehaviorRecord] {
        return records.values
            .filter { $0.state == .learned }
            .sorted {
                if $0.bundleID == $1.bundleID { return $0.shortcut < $1.shortcut }
                return $0.bundleID < $1.bundleID
            }
    }

    func recordKeyboardInvocation(bundleID: String, shortcut: String) {
        let k = key(bundleID, shortcut)
        var rec = records[k] ?? BehaviorRecord(bundleID: bundleID, shortcut: shortcut, menuTitle: "")
        rec.keyboardCount += 1
        rec.mouseSinceKeyboard = 0
        if rec.state == .active && rec.keyboardCount >= learnedThreshold {
            rec.state = .learned
            SemanticLogger.shared.log("Learned: \(shortcut) [\(bundleID)] — retiring hint")
        }
        records[k] = rec
        publish()
        scheduleSave()
    }
}
