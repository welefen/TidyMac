import Foundation

/// Download caches of the common package managers. Only paths that exist on the
/// current machine are reported.
enum PackageCacheScanner {
    private struct Definition {
        let relativePath: String
        let name: String
        let safety: SafetyLevel
        let detail: String
    }

    private static let definitions: [Definition] = [
        Definition(relativePath: ".npm/_cacache", name: L("npm 缓存"), safety: .safe,
                   detail: L("删除后首次安装依赖会重新下载")),
        Definition(relativePath: "Library/pnpm/store", name: "pnpm Store", safety: .caution,
                   detail: L("pnpm 的全局内容仓库，删除后需重新下载依赖")),
        Definition(relativePath: "Library/Caches/Homebrew", name: L("Homebrew 缓存"), safety: .safe,
                   detail: L("删除后重新安装软件包时会再次下载")),
        Definition(relativePath: "Library/Caches/pip", name: L("pip 缓存"), safety: .safe,
                   detail: L("删除后首次安装 Python 包会重新下载")),
        Definition(relativePath: "Library/Caches/CocoaPods", name: L("CocoaPods 缓存"), safety: .safe,
                   detail: L("删除后首次安装 Pod 会重新下载")),
        Definition(relativePath: "Library/Caches/org.swift.swiftpm", name: L("SwiftPM 缓存"), safety: .safe,
                   detail: L("删除后首次解析 Swift 包会重新下载")),
        Definition(relativePath: ".gradle/caches", name: L("Gradle 缓存"), safety: .safe,
                   detail: L("删除后首次构建会重新下载依赖")),
        Definition(relativePath: "Library/Caches/go-build", name: L("Go 构建缓存"), safety: .safe,
                   detail: L("删除后首次编译会重新生成")),
        Definition(relativePath: ".cargo/registry/cache", name: L("Cargo 缓存"), safety: .safe,
                   detail: L("删除后首次构建 Rust 项目会重新下载"))
    ]

    /// Paths claimed by this scanner that live under `~/Library/Caches`.
    static var reservedLibraryCachesPaths: [String] {
        definitions
            .map { HomePaths.url($0.relativePath).path }
            .filter { SafetyPolicy.isDescendant($0, of: HomePaths.url("Library/Caches").path) }
    }

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
                id: "package:" + url.path,
                name: definition.name,
                urls: [url],
                byteCount: footprint.bytes,
                kind: .packageCache,
                safety: definition.safety,
                detail: definition.detail,
                modifiedAt: footprint.lastModified,
                isSelected: true
            ))
        }
        return items
    }
}
