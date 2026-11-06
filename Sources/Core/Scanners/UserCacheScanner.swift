import Foundation

/// `~/Library/Caches`: one item per top-level app cache directory/file that is at
/// least 1 MB. The 12 largest are shown individually, the rest are folded into
/// one L("其他应用缓存") item.
enum UserCacheScanner {
    static let minimumBytes: Int64 = 1_000_000
    static let displayLimit = 12

    static func items(exclusions: ScanExclusions, isCancelled: () -> Bool) -> [ScanItem] {
        let caches = HomePaths.url("Library/Caches")
        guard HomePaths.exists(caches) else { return [] }

        // Browser and package-manager caches have dedicated categories. Reserve
        // them here so the same bytes are never reported twice.
        let reserved = ScanExclusions(BrowserCacheScanner.reservedPaths
                                      + PackageCacheScanner.reservedLibraryCachesPaths)
        let combined = ScanExclusions(exclusions.allPaths + reserved.allPaths)

        var items: [ScanItem] = []
        for child in ScanFileTool.children(of: caches) {
            if isCancelled() || Task.isCancelled { break }
            if combined.covers(child) { continue }
            let footprint = ScanFileTool.footprint(of: child, exclusions: combined, isCancelled: isCancelled)
            guard footprint.bytes >= minimumBytes else { continue }
            items.append(ScanItem(
                id: "cache:" + child.path,
                name: ScanFileTool.name(of: child),
                urls: [child],
                byteCount: footprint.bytes,
                kind: .cache,
                safety: .safe,
                detail: nil,
                modifiedAt: footprint.lastModified,
                isSelected: true
            ))
        }

        return ScanAggregate.compact(items,
                                     limit: displayLimit,
                                     aggregateID: "cache:other",
                                     aggregateName: L("其他应用缓存"),
                                     aggregateKind: .cache,
                                     aggregateSafety: .safe,
                                     aggregateDetail: L("包含 {count} 个应用缓存项目，可安全重建"))
    }
}
