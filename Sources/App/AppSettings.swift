import Foundation
import Combine

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

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
        static let appearance = "settings.appearance"
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

    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults

    private init() {
        // Demo runs (screenshots / design review) must never touch the user's
        // real settings or clean history. Use an isolated defaults suite.
        let demo = CommandLine.arguments.contains("--demo")
            || ProcessInfo.processInfo.environment["TIDYMAC_DEMO"] == "1"
        let store: UserDefaults
        if demo {
            let suiteName = "com.tidymac.clean.demo"
            let suite = UserDefaults(suiteName: suiteName) ?? .standard
            suite.removePersistentDomain(forName: suiteName)
            store = suite
        } else {
            store = .standard
        }
        self.defaults = store

        defaults.register(defaults: [
            Keys.moveToTrash: true,
            Keys.confirmBeforeClean: true,
            Keys.excludedPaths: [],
            Keys.totalFreedBytes: 0,
            Keys.cleanCount: 0,
            Keys.showSystemApps: false,
            Keys.reduceMotion: false,
            Keys.appearance: AppAppearance.system.rawValue
        ])
        moveToTrash = defaults.bool(forKey: Keys.moveToTrash)
        confirmBeforeClean = defaults.bool(forKey: Keys.confirmBeforeClean)
        excludedPaths = defaults.stringArray(forKey: Keys.excludedPaths) ?? []
        totalFreedBytes = Int64(defaults.double(forKey: Keys.totalFreedBytes))
        cleanCount = defaults.integer(forKey: Keys.cleanCount)
        lastCleanDate = defaults.object(forKey: Keys.lastCleanDate) as? Date
        showSystemApps = defaults.bool(forKey: Keys.showSystemApps)
        reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        if let data = defaults.data(forKey: Keys.history),
           let decoded = try? JSONDecoder().decode([CleanHistoryEntry].self, from: data) {
            history = decoded
        } else {
            history = []
        }

        if demo {
            let now = Date()
            let calendar = Calendar.current
            totalFreedBytes = 38_600_000_000
            cleanCount = 12
            lastCleanDate = calendar.date(byAdding: .day, value: -3, to: now)
            history = [
                CleanHistoryEntry(date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                                  freedBytes: 4_280_000_000, itemCount: 21),
                CleanHistoryEntry(date: calendar.date(byAdding: .day, value: -9, to: now) ?? now,
                                  freedBytes: 2_140_000_000, itemCount: 13),
                CleanHistoryEntry(date: calendar.date(byAdding: .day, value: -18, to: now) ?? now,
                                  freedBytes: 6_720_000_000, itemCount: 28)
            ]
        }

        // Demo screenshot / QA override.
        if let raw = ProcessInfo.processInfo.environment["TIDYMAC_APPEARANCE"],
           let parsed = AppAppearance(rawValue: raw.lowercased()) {
            appearance = parsed
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
