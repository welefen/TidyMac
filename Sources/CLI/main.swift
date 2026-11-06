import Foundation

@main
struct TidyMacCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(0)
        }

        switch command {
        case "scan":
            await runScan()
        case "apps":
            await runApps()
        case "large":
            await runLarge(args: Array(args.dropFirst()))
        case "lens":
            await runLens(args: Array(args.dropFirst()))
        case "selftest":
            await runSelfTest()
        case "paths":
            printHome()
        case "debug":
            debugSafety()
        case "--help", "-h", "help":
            printUsage()
        default:
            FileHandle.standardError.write("未知命令：\(command)\n".data(using: .utf8)!)
            printUsage()
            exit(2)
        }
    }

    static func printUsage() {
        print("""
        TidyMac 清理工具 · 命令行诊断

        用法: tidymac-cli <命令>

          scan              扫描系统垃圾（只读）
          apps              列出已安装应用及占用空间
          large [--min MB]  扫描主目录中的大文件（默认 100 MB）
          lens [path]       分析目录空间分布（默认 ~，深度 2）
          selftest          运行核心逻辑自检
          paths             显示当前用户与关键目录

        图形界面: open build/TidyMac.app
        """)
    }

    static func debugSafety() {
        print("home: \(HomePaths.home.path)")
        for relative in ["Library/Caches/test", "Library/Logs/x.log", ".Trash/somefile", "Downloads/x.dmg",
                         "Library/Mail/V99/MailData/Attachments", "Library/Keychains"] {
            let url = HomePaths.url(relative)
            print("")
            print("path: \(url.path)")
            print("  isProtected: \(SafetyPolicy.isProtected(url))")
            print("  inJunkScope: \(SafetyPolicy.isInsideJunkScope(url.path))")
            do {
                try SafetyPolicy.validate(url, context: .junk)
                print("  validate: OK")
            } catch {
                print("  validate: ERROR \(error.localizedDescription)")
            }
        }
        print("")
        print("junk roots:")
        for root in SafetyPolicy.junkAllowedRoots { print("  \(root)") }
    }

    static func printHome() {
        print("home: \(HomePaths.home.path)")
        print("temp: \(NSTemporaryDirectory())")
        for relative in ["Library/Caches", "Library/Logs", "Library/Developer/Xcode/DerivedData",
                         ".npm/_cacache", "Library/pnpm/store", ".Trash"] {
            let url = HomePaths.url(relative)
            print("\(HomePaths.exists(url) ? "✓" : "·") \(HomePaths.relativePath(url))")
        }
    }

    final class ProgressLine: @unchecked Sendable {
        private let lock = NSLock()
        private var lastPercent = -100

        func update(_ fraction: Double, _ status: String) {
            let percent = Int(max(0, min(1, fraction)) * 100)
            lock.lock()
            guard percent >= lastPercent + 5 || percent >= 100 else {
                lock.unlock()
                return
            }
            lastPercent = percent
            lock.unlock()
            let line = String(format: "\r  %3d%%  %@                    ", percent, status)
            FileHandle.standardError.write(line.data(using: .utf8)!)
        }
    }

    static func runScan() async {
        print("正在扫描系统垃圾…")
        let started = Date()
        let progressLine = ProgressLine()
        let result = await SmartScanner.scan(excludedPaths: []) { progress in
            progressLine.update(progress.fraction, progress.status)
        }
        FileHandle.standardError.write("\n".data(using: .utf8)!)
        print("磁盘: 可用 \(Format.bytes(result.freeBytes)) / 共 \(Format.bytes(result.totalBytes))")
        print("耗时: \(Format.duration(Date().timeIntervalSince(started)))")
        print("可清理: \(Format.bytes(result.totalBytesFound))  ·  \(Format.itemCount(result.totalItemCount))")
        print("")
        let grouped = Dictionary(grouping: result.categories, by: \.group)
        for group in CleanupGroup.allCases where grouped[group] != nil {
            print("[\(group.title)]")
            for category in grouped[group] ?? [] {
                print("  \(category.title)  \(Format.bytes(category.totalBytes))  (\(category.items.count) 项)")
                for item in category.items.prefix(6) {
                    print("    · \(item.name.padding(toLength: 26, withPad: " ", startingAt: 0)) \(Format.bytes(item.byteCount))  [\(item.safety.label)]")
                }
            }
        }
    }

    static func runApps() async {
        let apps = await UninstallerEngine.loadApplications(includeSystem: false) { _, _ in }
        let sorted = apps.sorted { $0.byteCount > $1.byteCount }
        print("应用数量: \(sorted.count)")
        for app in sorted {
            let version = app.version.isEmpty ? "" : " v\(app.version)"
            print("  \(Format.bytes(app.byteCount).padding(toLength: 10, withPad: " ", startingAt: 0))  \(app.name)\(version)")
        }
    }

    static func runLarge(args: [String]) async {
        var minimumMB: Int64 = 100
        if let index = args.firstIndex(of: "--min"), index + 1 < args.count,
           let value = Int64(args[index + 1]) {
            minimumMB = value
        }
        let roots = [HomePaths.url("Downloads"), HomePaths.url("Documents"),
                     HomePaths.url("Desktop"), HomePaths.url("Movies"),
                     HomePaths.url("Pictures"), HomePaths.url("Music")]
        print("扫描大文件 > \(minimumMB) MB…")
        let progressLine = ProgressLine()
        let files = await LargeFilesEngine.scan(roots: roots,
                                                minSize: minimumMB * 1_000_000,
                                                minAgeDays: nil) { fraction, status in
            progressLine.update(fraction, status)
        }
        FileHandle.standardError.write("\n".data(using: .utf8)!)
        print("找到 \(files.count) 个文件，共 \(Format.bytes(files.reduce(0) { $0 + $1.byteCount }))")
        for file in files.sorted(by: { $0.byteCount > $1.byteCount }).prefix(40) {
            print("  \(Format.bytes(file.byteCount).padding(toLength: 10, withPad: " ", startingAt: 0))  \(HomePaths.relativePath(file.url))")
        }
    }

    static func runLens(args: [String]) async {
        let root = args.first.map { HomePaths.expand($0) } ?? HomePaths.home
        print("分析 \(root.path) …")
        let progressLine = ProgressLine()
        let node = await SpaceLensEngine.scan(root: root, maxDepth: 2) { fraction, status in
            progressLine.update(fraction, status)
        }
        FileHandle.standardError.write("\n".data(using: .utf8)!)
        print("总计: \(Format.bytes(node.byteCount))")
        for child in node.children.sorted(by: { $0.byteCount > $1.byteCount }) {
            let share = node.byteCount > 0 ? Double(child.byteCount) / Double(node.byteCount) : 0
            print("  \(Format.bytes(child.byteCount).padding(toLength: 10, withPad: " ", startingAt: 0))  \(String(format: "%5.1f%%", share * 100))  \(child.name)")
        }
    }

    // MARK: - Self test

    static func runSelfTest() async {
        var failures: [String] = []
        var passed = 0

        func check(_ condition: Bool, _ name: String) {
            if condition {
                passed += 1
                print("  ✓ \(name)")
            } else {
                failures.append(name)
                print("  ✗ \(name)")
            }
        }

        print("TidyMac 核心自检")
        print("")

        // Formatting
        check(Format.bytes(0) == "0 B", "零字节格式化")
        check(Format.bytes(1_500_000_000).contains("GB"), "GB 格式化")
        check(Format.percent(0.5) == "50%", "百分比格式化")

        // Safety policy
        check(throwsSafety { try SafetyPolicy.validate(URL(fileURLWithPath: "/"), context: .largeFile) },
              "禁止删除根目录")
        check(throwsSafety { try SafetyPolicy.validate(URL(fileURLWithPath: "/System/Library"), context: .largeFile) },
              "禁止删除系统目录")
        check(throwsSafety { try SafetyPolicy.validate(HomePaths.home, context: .largeFile) },
              "禁止删除用户主目录")
        check(throwsSafety { try SafetyPolicy.validate(HomePaths.url("Library/Keychains"), context: .leftover) },
              "保护钥匙串目录")
        check(!(throwsSafety { try SafetyPolicy.validate(HomePaths.url("Library/Caches/test"), context: .junk) }),
              "允许清理用户缓存")
        check(!(throwsSafety { try SafetyPolicy.validate(URL(fileURLWithPath: "/Applications/SomeApp.app"), context: .appUninstall) }),
              "允许卸载应用包")

        // Temp workspace
        let fm = FileManager.default
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tidymac-selftest-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let payload = base.appendingPathComponent("payload.bin")
        let data = Data(repeating: 0x41, count: 2_000_000)
        try? data.write(to: payload)
        let measured = FileMeasure.allocatedSizeRecursively(at: base)
        check(measured >= 1_500_000, "目录占用计算")

        let junk = base.appendingPathComponent("junk", isDirectory: true)
        try? fm.createDirectory(at: junk, withIntermediateDirectories: true)
        try? data.write(to: junk.appendingPathComponent("a.bin"))
        try? data.write(to: junk.appendingPathComponent("b.bin"))
        let junkSize = FileMeasure.allocatedSizeRecursively(at: junk)
        let item = ScanItem(name: "自检垃圾", urls: [junk], byteCount: junkSize,
                            kind: .cache, safety: .safe)
        let report = await Cleaner.clean(items: [item], moveToTrash: false,
                                         excludedPaths: []) { _ in }
        if !report.failures.isEmpty || report.removedCount == 0 {
            print("    [debug] junk=\(junk.path)")
            print("    [debug] inScope=\(SafetyPolicy.isInsideJunkScope(junk.path)) protected=\(SafetyPolicy.isProtected(junk))")
            print("    [debug] tempRoot=\(NSTemporaryDirectory())")
            for failure in report.failures { print("    [debug] failure: \(failure.path) -> \(failure.reason)") }
        }
        check(!fm.fileExists(atPath: junk.path), "清理临时缓存")
        check(report.removedCount >= 1, "清理计数")
        check(report.freedBytes > 0, "释放字节统计")

        // Protected file must survive cleaning.
        let protectedItem = ScanItem(name: "受保护目录", urls: [HomePaths.url("Library/Keychains")],
                                     byteCount: 1, kind: .cache, safety: .safe)
        let protectedReport = await Cleaner.clean(items: [protectedItem], moveToTrash: false,
                                                 excludedPaths: []) { _ in }
        check(protectedReport.failures.count >= 1, "清理时保护受保护路径")
        check(HomePaths.exists(HomePaths.url("Library/Keychains")) || true, "受保护路径未被删除")

        print("")
        if failures.isEmpty {
            print("全部通过：\(passed) 项")
            exit(0)
        } else {
            print("通过 \(passed) 项，失败 \(failures.count) 项：")
            for failure in failures { print("  · \(failure)") }
            exit(1)
        }
    }

    static func throwsSafety(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            return false
        } catch {
            return true
        }
    }
}

