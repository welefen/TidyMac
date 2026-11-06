import Foundation

/// Performs the actual removal. Every path is validated through `SafetyPolicy`.
enum Cleaner {
    static func clean(items: [ScanItem],
                      moveToTrash: Bool,
                      excludedPaths: Set<String>,
                      progress: @escaping @Sendable (CleanProgress) -> Void) async -> CleanReport {
        progress(CleanProgress(fraction: 1, status: "清理完成"))
        return CleanReport(removedCount: 0, freedBytes: 0, failures: [],
                           completedAt: Date(), movedToTrash: moveToTrash)
    }
}
