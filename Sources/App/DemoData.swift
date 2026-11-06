import Foundation

/// Deterministic sample content used by `--demo` mode (screenshots, design review,
/// and UI development without touching the user's real files).
enum DemoData {
    private static let home = HomePaths.home

    private static func mb(_ value: Int64) -> Int64 { value * 1_000_000 }
    private static func gb(_ value: Double) -> Int64 { Int64(value * 1_000_000_000) }
    private static func url(_ relative: String) -> URL { HomePaths.url(relative) }
    private static func past(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    static var diskInfo: DiskInfo {
        DiskInfo(totalBytes: gb(994), freeBytes: gb(182.6), volumeName: "Macintosh HD")
    }

    static func scanResult() -> SmartScanResult {
        SmartScanResult(categories: categories,
                        freeBytes: diskInfo.freeBytes,
                        totalBytes: diskInfo.totalBytes,
                        scannedAt: Date().addingTimeInterval(-42),
                        duration: 8.4)
    }

    static var categories: [ScanCategory] {
        [
            ScanCategory(
                id: "system-cache",
                title: "用户缓存",
                subtitle: "应用运行时生成的临时数据，可安全重建",
                symbol: "shippingbox.fill",
                tone: .mint,
                group: .systemJunk,
                items: [
                    item("Safari 缓存", "Library/Caches/com.apple.Safari", mb(512), .cache, .safe),
                    item("Chrome 缓存", "Library/Caches/Google/Chrome", mb(286), .cache, .safe),
                    item("Spotify 缓存", "Library/Caches/com.spotify.client", mb(184), .cache, .safe),
                    item("Photos 缩略图", "Library/Caches/com.apple.Photos", mb(96), .cache, .safe),
                    item("其他应用缓存", "Library/Caches", mb(64), .cache, .safe,
                         detail: "包含 38 个应用缓存目录")
                ]
            ),
            ScanCategory(
                id: "logs",
                title: "日志与崩溃报告",
                subtitle: "诊断日志与旧崩溃记录",
                symbol: "doc.text.magnifyingglass",
                tone: .blue,
                group: .systemJunk,
                items: [
                    item("系统日志", "Library/Logs", mb(128), .log, .safe),
                    item("应用日志", "Library/Logs/DiagnosticReports", mb(88), .log, .safe),
                    item("崩溃报告", "Library/Application Support/CrashReporter", mb(46), .crashReport, .safe),
                    item("窗口恢复状态", "Library/Saved Application State", mb(32), .savedState, .safe)
                ]
            ),
            ScanCategory(
                id: "trash",
                title: "废纸篓",
                subtitle: "已删除但仍占用磁盘空间的项目",
                symbol: "trash.fill",
                tone: .orange,
                group: .trash,
                items: [
                    item("废纸篓", ".Trash", mb(1120), .trash, .safe,
                         detail: "清空后将无法恢复")
                ]
            ),
            ScanCategory(
                id: "xcode",
                title: "Xcode 构建缓存",
                subtitle: "DerivedData、设备支持与模拟器缓存",
                symbol: "hammer.fill",
                tone: .purple,
                group: .developerJunk,
                items: [
                    item("DerivedData", "Library/Developer/Xcode/DerivedData", mb(2100), .derivedData, .safe,
                         detail: "下次构建会自动重新生成"),
                    item("iOS DeviceSupport", "Library/Developer/Xcode/iOS DeviceSupport", mb(860), .deviceSupport, .caution),
                    item("模拟器缓存", "Library/Developer/CoreSimulator/Caches", mb(420), .simulatorCache, .safe),
                    item("Xcode 文档缓存", "Library/Developer/Xcode/DocumentationCache", mb(188), .cache, .safe)
                ]
            ),
            ScanCategory(
                id: "dev-packages",
                title: "包管理器缓存",
                subtitle: "npm、Homebrew、pip 等下载缓存",
                symbol: "shippingbox.and.arrow.backward.fill",
                tone: .teal,
                group: .developerJunk,
                items: [
                    item("npm 缓存", ".npm/_cacache", mb(486), .packageCache, .safe),
                    item("pnpm Store", "Library/pnpm/store", mb(412), .packageCache, .caution),
                    item("Homebrew 缓存", "Library/Caches/Homebrew", mb(286), .packageCache, .safe),
                    item("pip 缓存", "Library/Caches/pip", mb(142), .packageCache, .safe),
                    item("CocoaPods 缓存", "Library/Caches/CocoaPods", mb(96), .packageCache, .safe),
                    item("SwiftPM 缓存", "Library/Caches/org.swift.swiftpm", mb(64), .packageCache, .safe)
                ]
            ),
            ScanCategory(
                id: "browser",
                title: "浏览器数据",
                subtitle: "网页缓存与旧版本资源，建议先退出浏览器",
                symbol: "safari.fill",
                tone: .blue,
                group: .browserJunk,
                items: [
                    item("Safari 网页缓存", "Library/Caches/com.apple.Safari", mb(512), .browserCache, .caution),
                    item("Chrome 网页缓存", "Library/Caches/Google/Chrome", mb(386), .browserCache, .caution),
                    item("Firefox 缓存", "Library/Caches/Firefox", mb(224), .browserCache, .caution),
                    item("Edge 缓存", "Library/Caches/Microsoft Edge", mb(118), .browserCache, .caution)
                ]
            ),
            ScanCategory(
                id: "mail",
                title: "邮件附件",
                subtitle: "已下载至本地的附件副本，邮件本身不受影响",
                symbol: "envelope.fill",
                tone: .pink,
                group: .mailAttachments,
                items: [
                    item("邮件附件", "Library/Mail", mb(640), .mailAttachment, .caution,
                         detail: "共 1,284 个附件，可重新下载")
                ]
            ),
            ScanCategory(
                id: "ios-backups",
                title: "iOS 设备备份",
                subtitle: "旧设备备份，删除后需重新备份",
                symbol: "iphone.gen3",
                tone: .yellow,
                group: .iosBackups,
                items: [
                    item("iPhone 15 Pro 备份", "Library/Application Support/MobileSync/Backup", mb(4200), .iosBackup, .risky,
                         detail: "2025/08/12 · 默认不勾选", isSelected: false)
                ]
            )
        ]
    }

    private static func item(_ name: String, _ relativePath: String, _ bytes: Int64,
                             _ kind: ItemKind, _ safety: SafetyLevel,
                             detail: String? = nil, isSelected: Bool = true) -> ScanItem {
        ScanItem(name: name,
                 urls: [url(relativePath)],
                 byteCount: bytes,
                 kind: kind,
                 safety: safety,
                 detail: detail,
                 modifiedAt: past(days: 20),
                 isSelected: isSelected)
    }

    // MARK: - Uninstaller

    static var applications: [InstalledApp] {
        [
            app("ChatGPT", "com.openai.chat", "1.2026.105", mb(486), lastUsedDays: 0),
            app("WeChat", "com.tencent.xinWeChat", "4.1.2", mb(1240), lastUsedDays: 1),
            app("Google Chrome", "com.google.Chrome", "141.0.7390.66", mb(1460), lastUsedDays: 0),
            app("Docker", "com.docker.docker", "4.48.0", mb(2180), lastUsedDays: 4),
            app("GarageBand", "com.apple.GarageBand10", "10.4.12", mb(1860), lastUsedDays: 47),
            app("iMovie", "com.apple.iMovieApp", "10.4.4", mb(2420), lastUsedDays: 96),
            app("DevEco-Studio", "com.huawei.devecostudio", "6.0.1", mb(3620), lastUsedDays: 12),
            app("Keynote Creator Studio", "com.apple.KeynoteCreator", "1.2", mb(1120), lastUsedDays: 64),
            app("Trae CN", "com.trae.cn", "2.4.0", mb(820), lastUsedDays: 2),
            app("豆包浏览器", "com.doubao.browser", "1.8.3", mb(640), lastUsedDays: 7)
        ]
    }

    private static func app(_ name: String, _ bundleID: String, _ version: String,
                            _ bytes: Int64, lastUsedDays: Int) -> InstalledApp {
        let appURL = URL(fileURLWithPath: "/Applications/\(name).app")
        return InstalledApp(name: name,
                            bundleID: bundleID,
                            version: version,
                            url: appURL,
                            byteCount: bytes,
                            lastUsed: past(days: lastUsedDays),
                            isSystem: false,
                            executableName: name,
                            iconPath: appURL.path)
    }

    static func leftovers(for app: InstalledApp) -> [LeftoverItem] {
        guard let bundleID = app.bundleID else { return [] }
        let entries: [(String, String, LeftoverKind, Int64)] = [
            (bundleID, "Library/Application Support/\(bundleID)", .applicationSupport, app.byteCount / 5),
            (bundleID, "Library/Caches/\(bundleID)", .caches, app.byteCount / 8),
            ("\(bundleID).plist", "Library/Preferences/\(bundleID).plist", .preferences, 82_000),
            ("\(app.name)", "Library/Saved Application State/\(bundleID).savedState", .savedState, 1_400_000),
            ("\(bundleID)", "Library/Logs/\(bundleID)", .logs, 3_200_000)
        ]
        return entries.map { name, path, kind, size in
            LeftoverItem(name: name,
                         url: url(path),
                         byteCount: size,
                         kind: kind,
                         isSelected: true)
        }
    }

    // MARK: - Large files

    static var largeFiles: [LargeFile] {
        [
            largeFile("Xcode_26.1_Release_Candidate.xip", "Downloads/Xcode_26.1_Release_Candidate.xip", gb(9.6), days: 32, .archive),
            largeFile("冰岛旅行_4K.mp4", "Movies/冰岛旅行_4K.mp4", gb(8.4), days: 420, .video),
            largeFile("macOS_Sequoia_15.5.dmg", "Downloads/macOS_Sequoia_15.5.dmg", gb(12.8), days: 96, .diskImage),
            largeFile("设计素材备份_2024.zip", "Documents/设计素材备份_2024.zip", gb(3.2), days: 240, .archive),
            largeFile("婚礼照片_原片.zip", "Pictures/婚礼照片_原片.zip", gb(2.8), days: 510, .archive),
            largeFile("产品演示_最终版.mov", "Movies/产品演示_最终版.mov", gb(2.1), days: 15, .video),
            largeFile("播客合集.m4a", "Music/播客合集.m4a", gb(1.4), days: 180, .audio),
            largeFile("数据集_训练样本.csv", "Documents/数据集_训练样本.csv", gb(1.1), days: 65, .document),
            largeFile("Docker.raw", "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", gb(18.4), days: 2, .other),
            largeFile("旧版项目归档.tar.gz", "Documents/旧版项目归档.tar.gz", mb(860), days: 700, .archive)
        ]
    }

    private static func largeFile(_ name: String, _ path: String, _ bytes: Int64,
                                  days: Int, _ kind: LargeFileKind) -> LargeFile {
        LargeFile(url: url(path), byteCount: bytes, modifiedAt: past(days: days),
                  kind: kind, isSelected: false)
    }

    // MARK: - Space Lens

    static var spaceTree: SpaceNode {
        let children = [
            node("Library", "Library", gb(286.4), children: [
                node("Application Support", "Library/Application Support", gb(98.2)),
                node("Developer", "Library/Developer", gb(74.6), children: [
                    node("Xcode", "Library/Developer/Xcode", gb(52.4)),
                    node("CoreSimulator", "Library/Developer/CoreSimulator", gb(18.8)),
                    node("其他", "Library/Developer", gb(3.4))
                ]),
                node("Caches", "Library/Caches", gb(32.8)),
                node("Containers", "Library/Containers", gb(28.4)),
                node("Group Containers", "Library/Group Containers", gb(22.1)),
                node("Mobile Documents", "Library/Mobile Documents", gb(18.6)),
                node("其他", "Library", gb(11.7))
            ]),
            node("Movies", "Movies", gb(68.2)),
            node("Pictures", "Pictures", gb(42.6)),
            node("Downloads", "Downloads", gb(34.8)),
            node("Documents", "Documents", gb(21.4)),
            node("Applications", "Applications", gb(18.6)),
            node("Music", "Music", gb(9.8)),
            node("Desktop", "Desktop", gb(6.4)),
            node("其他", "其他", gb(24.2))
        ]
        return SpaceNode(name: home.lastPathComponent,
                         url: home,
                         byteCount: gb(512.4),
                         isDirectory: true,
                         childCount: children.count,
                         children: children)
    }

    private static func node(_ name: String, _ relativePath: String, _ bytes: Int64,
                             children: [SpaceNode] = []) -> SpaceNode {
        SpaceNode(name: name,
                  url: relativePath == "其他" ? home : url(relativePath),
                  byteCount: bytes,
                  isDirectory: true,
                  childCount: children.count,
                  children: children)
    }
}
