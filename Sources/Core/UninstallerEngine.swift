import Foundation

enum UninstallerEngine {
    static func loadApplications(includeSystem: Bool,
                                 progress: @escaping @Sendable (Double, String) -> Void) async -> [InstalledApp] {
        progress(1, "已加载应用")
        return []
    }

    static func findLeftovers(for app: InstalledApp,
                              progress: @escaping @Sendable (Double, String) -> Void) async -> [LeftoverItem] {
        progress(1, "已检查残留")
        return []
    }

    static func uninstall(app: InstalledApp,
                          leftovers: [LeftoverItem],
                          moveToTrash: Bool,
                          progress: @escaping @Sendable (Double, String) -> Void) async -> CleanReport {
        progress(1, "已卸载")
        return CleanReport(removedCount: 0, freedBytes: 0, failures: [],
                           completedAt: Date(), movedToTrash: moveToTrash)
    }
}
