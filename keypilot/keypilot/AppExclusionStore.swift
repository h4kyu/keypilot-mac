import Foundation

final class AppExclusionStore {
    static let shared = AppExclusionStore()

    private let key = "keypilot.excludedBundleIDs"
    private let defaults = UserDefaults.standard

    private var excluded: Set<String> {
        get { Set(defaults.stringArray(forKey: key) ?? []) }
        set { defaults.set(Array(newValue), forKey: key) }
    }

    func isExcluded(_ bundleID: String) -> Bool {
        excluded.contains(bundleID)
    }

    func toggle(_ bundleID: String) {
        var set = excluded
        if set.contains(bundleID) { set.remove(bundleID) } else { set.insert(bundleID) }
        excluded = set
    }
}
