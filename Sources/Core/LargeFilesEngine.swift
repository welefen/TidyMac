import Foundation

enum LargeFilesEngine {
    static func scan(roots: [URL],
                     minSize: Int64,
                     minAgeDays: Int?,
                     progress: @escaping @Sendable (Double, String) -> Void) async -> [LargeFile] {
        progress(1, "扫描完成")
        return []
    }

    static func trash(files: [LargeFile],
                      progress: @escaping @Sendable (Double, String) -> Void) async -> CleanReport {
        progress(1, "已移到废纸篓")
        return CleanReport(removedCount: 0, freedBytes: 0, failures: [],
                           completedAt: Date(), movedToTrash: true)
    }
}
