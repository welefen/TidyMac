import Foundation

/// Browser caches live under `~/Library/Caches` but are reported separately so
/// the user sees a dedicated L("浏览器数据") section. Every path listed here is
/// reserved out of the generic user-cache category to avoid double counting.
enum BrowserCacheScanner {
    private struct Definition {
        let relativePath: String
        let name: String
    }

    private static let definitions: [Definition] = [
        Definition(relativePath: "Library/Caches/com.apple.Safari", name: L("Safari 缓存")),
        Definition(relativePath: "Library/Caches/Google/Chrome", name: L("Chrome 缓存")),
        Definition(relativePath: "Library/Caches/Google/Chrome Canary", name: L("Chrome Canary 缓存")),
        Definition(relativePath: "Library/Caches/Firefox", name: L("Firefox 缓存")),
        Definition(relativePath: "Library/Caches/Microsoft Edge", name: L("Edge 缓存")),
        Definition(relativePath: "Library/Caches/com.microsoft.edgemac", name: L("Edge 缓存")),
        Definition(relativePath: "Library/Caches/com.brave.Browser", name: L("Brave 缓存")),
        Definition(relativePath: "Library/Caches/com.operasoftware.Opera", name: L("Opera 缓存"))
    ]

    /// Absolute paths claimed by this scanner; the user-cache scanner ignores them.
    static var reservedPaths: [String] {
        definitions.map { HomePaths.url($0.relativePath).path }
    }

    static func items(exclusions: ScanExclusions, isCancelled: () -> Bool) -> [ScanItem] {
        var items: [ScanItem] = []
        for definition in definitions {
            if isCancelled() || Task.isCancelled { break }
            let url = HomePaths.url(definition.relativePath)
            guard HomePaths.exists(url), !exclusions.covers(url) else { continue }
            let footprint = ScanFileTool.footprint(of: url, exclusions: exclusions, isCancelled: isCancelled)
            guard footprint.bytes > 0 else { continue }
            items.append(ScanItem(
                id: "browser:" + url.path,
                name: definition.name,
                urls: [url],
                byteCount: footprint.bytes,
                kind: .browserCache,
                safety: .caution,
                detail: L("建议先退出浏览器再清理，缓存会在下次浏览时自动重建"),
                modifiedAt: footprint.lastModified,
                isSelected: true
            ))
        }
        return items
    }
}
