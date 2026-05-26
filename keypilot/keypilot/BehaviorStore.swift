import Foundation
import AppKit

struct BehaviorRecord: Codable {
    let bundleID: String
    let shortcut: String
    var menuTitle: String
    var mouseCount: Int = 0
    var keyboardCount: Int = 0
    var lastShownAt: Date?
    var state: State = .active

    enum State: String, Codable {
        case active
        case learned
    }
}

final class BehaviorStore {
    static let shared = BehaviorStore()

    // Thresholds drawn from CLAUDE.md suppression spec.
    private let showAfterMouseCount = 1
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

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: BehaviorRecord].self, from: data) else {
            return
        }
        records = decoded
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

    // MARK: - Mouse path

    // Increments the mouse counter for this (app, shortcut). Returns true
    // if the overlay should be shown — false on .learned, on cooldown, or
    // below the mouse threshold.
    func recordMouseInvocation(bundleID: String, shortcut: String, menuTitle: String) -> Bool {
        let k = key(bundleID, shortcut)
        var rec = records[k] ?? BehaviorRecord(bundleID: bundleID, shortcut: shortcut, menuTitle: menuTitle)
        rec.menuTitle = menuTitle
        rec.mouseCount += 1

        let shouldShow: Bool = {
            if rec.state == .learned { return false }
            if let last = rec.lastShownAt, Date().timeIntervalSince(last) < cooldownSeconds { return false }
            return rec.mouseCount >= showAfterMouseCount
        }()

        if shouldShow {
            rec.lastShownAt = Date()
        }
        records[k] = rec
        scheduleSave()
        return shouldShow
    }

    // MARK: - Keyboard path

    // Increments the keyboard counter for this (app, shortcut). Once it
    // crosses learnedThreshold while still .active, retires the hint by
    // flipping to .learned.
    func recordKeyboardInvocation(bundleID: String, shortcut: String) {
        let k = key(bundleID, shortcut)
        var rec = records[k] ?? BehaviorRecord(bundleID: bundleID, shortcut: shortcut, menuTitle: "")
        rec.keyboardCount += 1
        if rec.state == .active && rec.keyboardCount >= learnedThreshold {
            rec.state = .learned
            SemanticLogger.shared.log("Learned: \(shortcut) [\(bundleID)] — retiring hint")
        }
        records[k] = rec
        scheduleSave()
    }
}
