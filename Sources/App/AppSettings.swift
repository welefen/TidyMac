import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let moveToTrash = "settings.moveToTrash"
        static let confirmBeforeClean = "settings.confirmBeforeClean"
        static let excludedPaths = "settings.excludedPaths"
        static let totalFreedBytes = "settings.totalFreedBytes"
        static let cleanCount = "settings.cleanCount"
        static let lastCleanDate = "settings.lastCleanDate"
        static let history = "settings.history"
        static let showSystemApps = "settings.showSystemApps"
        static let reduceMotion = "settings.reduceMotion"
    }

    @Published var moveToTrash: Bool {
        didSet { defaults.set(moveToTrash, forKey: Keys.moveToTrash) }
    }

    @Published var confirmBeforeClean: Bool {
        didSet { defaults.set(confirmBeforeClean, forKey: Keys.confirmBeforeClean) }
    }

    @Published var excludedPaths: [String] {
        didSet { defaults.set(excludedPaths, forKey: Keys.excludedPaths) }
    }

    @Published var totalFreedBytes: Int64 {
        didSet { defaults.set(totalFreedBytes, forKey: Keys.totalFreedBytes) }
    }

    @Published var cleanCount: Int {
        didSet { defaults.set(cleanCount, forKey: Keys.cleanCount) }
    }

    @Published var lastCleanDate: Date? {
        didSet { defaults.set(lastCleanDate, forKey: Keys.lastCleanDate) }
    }

    @Published var history: [CleanHistoryEntry] {
        didSet {
            if let data = try? JSONEncoder().encode(history) {
                defaults.set(data, forKey: Keys.history)
            }
        }
    }

    @Published var showSystemApps: Bool {
        didSet { defaults.set(showSystemApps, forKey: Keys.showSystemApps) }
    }

    @Published var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Keys.reduceMotion) }
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Keys.moveToTrash: true,
            Keys.confirmBeforeClean: true,
            Keys.excludedPaths: [],
            Keys.totalFreedBytes: 0,
            Keys.cleanCount: 0,
            Keys.showSystemApps: false,
            Keys.reduceMotion: false
        ])
        moveToTrash = defaults.bool(forKey: Keys.moveToTrash)
        confirmBeforeClean = defaults.bool(forKey: Keys.confirmBeforeClean)
        excludedPaths = defaults.stringArray(forKey: Keys.excludedPaths) ?? []
        totalFreedBytes = Int64(defaults.double(forKey: Keys.totalFreedBytes))
        cleanCount = defaults.integer(forKey: Keys.cleanCount)
        lastCleanDate = defaults.object(forKey: Keys.lastCleanDate) as? Date
        showSystemApps = defaults.bool(forKey: Keys.showSystemApps)
        reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        if let data = defaults.data(forKey: Keys.history),
           let decoded = try? JSONDecoder().decode([CleanHistoryEntry].self, from: data) {
            history = decoded
        } else {
            history = []
        }
    }

    func recordClean(_ report: CleanReport) {
        totalFreedBytes += report.freedBytes
        cleanCount += 1
        lastCleanDate = report.completedAt
        var newHistory = history
        newHistory.insert(CleanHistoryEntry(date: report.completedAt,
                                            freedBytes: report.freedBytes,
                                            itemCount: report.removedCount), at: 0)
        if newHistory.count > 20 { newHistory = Array(newHistory.prefix(20)) }
        history = newHistory
    }

    func addExclusion(_ rawPath: String) {
        let path = SafetyPolicy.normalized(HomePaths.expand(rawPath).path)
        guard !path.isEmpty, !excludedPaths.contains(path) else { return }
        excludedPaths.append(path)
    }

    func removeExclusion(_ path: String) {
        excludedPaths.removeAll { $0 == path }
    }

    func isExcluded(_ url: URL) -> Bool {
        let path = SafetyPolicy.normalized(url.path)
        return excludedPaths.contains { SafetyPolicy.isDescendant(path, of: $0) }
    }

    func resetStatistics() {
        totalFreedBytes = 0
        cleanCount = 0
        lastCleanDate = nil
        history = []
    }
}
