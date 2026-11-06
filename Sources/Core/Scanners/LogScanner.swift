import Foundation

/// Logs, crash reports and saved window state. All of these are diagnostics that
/// macOS and apps recreate on demand.
enum LogScanner {
    static let displayLimit = 12

    static func items(exclusions: ScanExclusions, isCancelled: () -> Bool) -> [ScanItem] {
        guard !isCancelled() else { return [] }

        // (url, kind, detail) candidates. The ~/Library/Logs children are listed
        // individually; DiagnosticReports is one of them and is tagged as crash
        // reports, so it is not added twice.
        var candidates: [(URL, ItemKind, String?)] = []

        let logs = HomePaths.url("Library/Logs")
        for child in ScanFileTool.children(of: logs, exclusions: exclusions) {
            if isCancelled() || Task.isCancelled { return [] }
            let isDiagnostics = child.lastPathComponent == "DiagnosticReports"
            candidates.append((child, isDiagnostics ? .crashReport : .log, nil))
        }

        let crashReporter = HomePaths.url("Library/Application Support/CrashReporter")
        if HomePaths.exists(crashReporter), !exclusions.covers(crashReporter) {
            candidates.append((crashReporter, .crashReport, L("应用崩溃报告，可安全删除")))
        }

        let savedState = HomePaths.url("Library/Saved Application State")
        if HomePaths.exists(savedState), !exclusions.covers(savedState) {
            candidates.append((savedState, .savedState, L("窗口恢复状态，删除后应用下次启动会重新创建")))
        }

        var items: [ScanItem] = []
        var seen = Set<String>()
        for (url, kind, detail) in candidates {
            if isCancelled() || Task.isCancelled { break }
            guard seen.insert(url.path).inserted else { continue }
            let footprint = ScanFileTool.footprint(of: url, exclusions: exclusions, isCancelled: isCancelled)
            guard footprint.bytes > 0 else { continue }
            items.append(ScanItem(
                id: "log:" + url.path,
                name: ScanFileTool.name(of: url),
                urls: [url],
                byteCount: footprint.bytes,
                kind: kind,
                safety: .safe,
                detail: detail,
                modifiedAt: footprint.lastModified,
                isSelected: true
            ))
        }

        return ScanAggregate.compact(items,
                                     limit: displayLimit,
                                     aggregateID: "log:other",
                                     aggregateName: L("其他日志"),
                                     aggregateKind: .log,
                                     aggregateSafety: .safe,
                                     aggregateDetail: L("包含 {count} 个日志项目，可安全删除"))
    }
}
