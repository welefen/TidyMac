import Foundation

/// Xcode build products, device support symbols and simulator caches.
enum XcodeScanner {
    private static let minimumBytes: Int64 = 1_000_000

    static func items(exclusions: ScanExclusions, isCancelled: () -> Bool) -> [ScanItem] {
        var items: [ScanItem] = []
        guard !isCancelled() else { return [] }

        // DerivedData: one item per project workspace.
        let derivedData = HomePaths.url("Library/Developer/Xcode/DerivedData")
        for child in ScanFileTool.children(of: derivedData, exclusions: exclusions) {
            if isCancelled() || Task.isCancelled { break }
            guard ScanFileTool.isDirectory(child) else { continue }
            let footprint = ScanFileTool.footprint(of: child, exclusions: exclusions, isCancelled: isCancelled)
            guard footprint.bytes >= minimumBytes else { continue }
            items.append(ScanItem(
                id: "xcode:derived:" + child.path,
                name: ScanFileTool.name(of: child),
                urls: [child],
                byteCount: footprint.bytes,
                kind: .derivedData,
                safety: .safe,
                detail: L("项目构建缓存，下次构建会自动重新生成"),
                modifiedAt: footprint.lastModified,
                isSelected: true
            ))
        }

        // iOS device support: one item per iOS version.
        let deviceSupport = HomePaths.url("Library/Developer/Xcode/iOS DeviceSupport")
        for child in ScanFileTool.children(of: deviceSupport, exclusions: exclusions) {
            if isCancelled() || Task.isCancelled { break }
            guard ScanFileTool.isDirectory(child) else { continue }
            let footprint = ScanFileTool.footprint(of: child, exclusions: exclusions, isCancelled: isCancelled)
            guard footprint.bytes >= minimumBytes else { continue }
            items.append(ScanItem(
                id: "xcode:device:" + child.path,
                name: ScanFileTool.name(of: child),
                urls: [child],
                byteCount: footprint.bytes,
                kind: .deviceSupport,
                safety: .caution,
                detail: L("设备调试符号，下次连接该版本设备时会重新生成"),
                modifiedAt: footprint.lastModified,
                isSelected: true
            ))
        }

        // Single-directory caches.
        items.append(contentsOf: singleItems(
            definitions: [
                (relativePath: "Library/Developer/CoreSimulator/Caches",
                 name: L("模拟器缓存"),
                 kind: .simulatorCache,
                 safety: .safe,
                 detail: L("模拟器缓存，下次启动模拟器时会重新生成")),
                (relativePath: "Library/Developer/Xcode/DocumentationCache",
                 name: L("Xcode 文档缓存"),
                 kind: .cache,
                 safety: .safe,
                 detail: L("Xcode 文档与 API 索引缓存，可重新下载"))
            ],
            exclusions: exclusions,
            isCancelled: isCancelled
        ))

        return items
    }

    private static func singleItems(
        definitions: [(relativePath: String, name: String, kind: ItemKind, safety: SafetyLevel, detail: String)],
        exclusions: ScanExclusions,
        isCancelled: () -> Bool
    ) -> [ScanItem] {
        var items: [ScanItem] = []
        for definition in definitions {
            if isCancelled() || Task.isCancelled { break }
            let url = HomePaths.url(definition.relativePath)
            guard HomePaths.exists(url), !exclusions.covers(url) else { continue }
            let footprint = ScanFileTool.footprint(of: url, exclusions: exclusions, isCancelled: isCancelled)
            guard footprint.bytes > 0 else { continue }
            items.append(ScanItem(
                id: "xcode:single:" + url.path,
                name: definition.name,
                urls: [url],
                byteCount: footprint.bytes,
                kind: definition.kind,
                safety: definition.safety,
                detail: definition.detail,
                modifiedAt: footprint.lastModified,
                isSelected: true
            ))
        }
        return items
    }
}
