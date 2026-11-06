import Foundation

/// Performs the actual removal. Every filesystem entry is validated through
/// `SafetyPolicy` before being touched, and failures never crash the app.
///
/// The trash item is special: `~/.Trash` itself is never deleted. Its children are
/// validated and removed one by one so the trash folder can keep working.
enum Cleaner {
    private static let fm = FileManager.default

    static func clean(items: [ScanItem],
                      moveToTrash: Bool,
                      excludedPaths: Set<String>,
                      progress: @escaping @Sendable (CleanProgress) -> Void) async -> CleanReport {
        let exclusions = ScanExclusions(excludedPaths)
        var removedCount = 0
        var freedBytes: Int64 = 0
        var failures: [CleanFailure] = []

        let total = max(1, items.count)
        progress(CleanProgress(fraction: 0, status: L("正在准备清理…")))

        if items.isEmpty {
            progress(CleanProgress(fraction: 1, status: L("没有需要清理的项目")))
            return CleanReport(removedCount: 0, freedBytes: 0, failures: [],
                               completedAt: Date(), movedToTrash: moveToTrash)
        }

        /// Validates, measures and removes one filesystem entry.
        func removeEntry(_ url: URL, forceRemove: Bool) {
            // Validation comes first: a protected path must be reported even when
            // it does not exist (the user may be probing a restricted location).
            do {
                try SafetyPolicy.validate(url, context: .junk)
            } catch {
                failures.append(CleanFailure(path: HomePaths.relativePath(url),
                                             reason: Self.reasonText(for: error)))
                return
            }

            // Already gone (or an empty placeholder): nothing to do, not a failure.
            guard Self.fm.fileExists(atPath: url.path) else { return }

            let bytes = FileMeasure.allocatedSize(ofItemAt: url)
            do {
                if moveToTrash && !forceRemove {
                    try Self.fm.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try Self.fm.removeItem(at: url)
                }
                freedBytes += bytes
                removedCount += 1
            } catch {
                failures.append(CleanFailure(path: HomePaths.relativePath(url),
                                             reason: Self.reasonText(for: error)))
            }
        }

        for (index, item) in items.enumerated() {
            if Task.isCancelled { break }
            progress(CleanProgress(fraction: Self.clamp(Double(index) / Double(total)),
                                   status: L("正在清理 \(item.name)…")))

            if item.kind == .trash {
                // Never remove the trash folder itself: empty its contents.
                let trashRoot = HomePaths.url(".Trash")
                for child in HomePaths.children(of: trashRoot) {
                    if Task.isCancelled { break }
                    if exclusions.covers(child) { continue }
                    if exclusions.containsExcludedDescendant(child) { continue }
                    removeEntry(child, forceRemove: true)
                }
            } else {
                for url in item.urls {
                    if Task.isCancelled { break }
                    if exclusions.covers(url) { continue }
                    // Never delete a whole tree that contains a user-excluded path.
                    if exclusions.containsExcludedDescendant(url) { continue }
                    removeEntry(url, forceRemove: false)
                }
            }

            progress(CleanProgress(fraction: Self.clamp(Double(index + 1) / Double(total)),
                                   status: item.kind == .trash ? L("已清空废纸篓") : L("已清理 \(item.name)")))
        }

        progress(CleanProgress(fraction: 1, status: L("清理完成")))
        return CleanReport(removedCount: removedCount,
                           freedBytes: freedBytes,
                           failures: failures,
                           completedAt: Date(),
                           movedToTrash: moveToTrash)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    /// Chinese, user-facing failure text.
    private static func reasonText(for error: Error) -> String {
        if let safety = error as? SafetyError, let description = safety.errorDescription {
            return description
        }
        let nsError = error as NSError
        switch (nsError.domain, nsError.code) {
        case (NSCocoaErrorDomain, NSFileWriteNoPermissionError):
            return L("没有权限删除，已跳过（可在系统设置中授权）")
        case (NSCocoaErrorDomain, NSFileReadNoPermissionError):
            return L("没有读取权限，已跳过")
        case (NSCocoaErrorDomain, NSFileNoSuchFileError), (NSCocoaErrorDomain, NSFileReadNoSuchFileError):
            return L("文件已不存在")
        case (NSCocoaErrorDomain, NSFileWriteVolumeReadOnlyError):
            return L("磁盘为只读，无法删除")
        case (NSPOSIXErrorDomain, Int(EPERM)), (NSPOSIXErrorDomain, Int(EACCES)):
            return L("没有权限删除，已跳过（可尝试授予完全磁盘访问权限）")
        case (NSPOSIXErrorDomain, Int(EBUSY)):
            return L("文件正在使用中，已跳过")
        case (NSPOSIXErrorDomain, Int(EROFS)):
            return L("磁盘为只读，无法删除")
        default:
            return L("删除失败：\(nsError.localizedDescription)")
        }
    }
}
