import Foundation

enum SnoozeDuration {
    case oneHour
    case today
    case thisWeek

    var endDate: Date {
        switch self {
        case .oneHour:
            return Date().addingTimeInterval(3600)
        case .today:
            // startOfDay(+1 day) rather than +86400 so it expires at midnight, not 24h from now.
            let cal = Calendar.current
            return cal.startOfDay(for: Date().addingTimeInterval(86400))
        case .thisWeek:
            return Date().addingTimeInterval(7 * 86400)
        }
    }

    var label: String {
        switch self {
        case .oneHour:  return "For 1 hour"
        case .today:    return "Until end of today"
        case .thisWeek: return "For this week"
        }
    }
}

final class SnoozeManager {
    static let shared = SnoozeManager()

    private let key = "keypilot.globalSnoozedUntil"
    private let defaults = UserDefaults.standard

    var globalSnoozedUntil: Date? {
        get { defaults.object(forKey: key) as? Date }
        set { defaults.set(newValue, forKey: key) }
    }

    var isSnoozed: Bool {
        guard let until = globalSnoozedUntil else { return false }
        return Date() < until
    }

    func snoozeFor(_ duration: SnoozeDuration) {
        let until = duration.endDate
        globalSnoozedUntil = until
        SemanticLogger.shared.log("Snoozed until \(ISO8601DateFormatter().string(from: until))")
    }

    func unsnooze() {
        globalSnoozedUntil = nil
        SemanticLogger.shared.log("Snooze cleared — coaching resumed")
    }
}
