import Foundation

/// Application discovery, leftover detection and safe uninstall.
///
/// Everything here is read-only until `uninstall` is called, and every
/// destructive step goes through `SafetyPolicy` first.
enum UninstallerEngine {
    private static let fm = FileManager.default
    private static let home = HomePaths.home
    private static let library = HomePaths.url("Library")

    private static let userApplicationRoots: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        HomePaths.url("Applications")
    ]
    private static let systemApplicationRoot = URL(fileURLWithPath: "/System/Applications",
                                                   isDirectory: true)

    /// How many app bundles are inspected in parallel. App size is measured with a
    /// recursive walk, so a small degree of concurrency hides I/O latency while
    /// keeping the disk busy enough without starving the UI.
    private static let applicationReadConcurrency = 4

    private struct LeftoverCandidate {
        let url: URL
        let kind: LeftoverKind
    }

    // MARK: - Loading applications

    static func loadApplications(includeSystem: Bool,
                                 progress: @escaping @Sendable (Double, String) -> Void) async -> [InstalledApp] {
        progress(0.01, L("正在查找已安装的应用…"))

        var roots = userApplicationRoots
        if includeSystem { roots.append(systemApplicationRoot) }

        var urls: [URL] = []
        var seen = Set<String>()
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for entry in entries where entry.pathExtension.lowercased() == "app" {
                let path = ToolsSupport.standardizedPath(entry)
                if seen.insert(path).inserted {
                    urls.append(entry)
                }
            }
        }

        guard !urls.isEmpty else {
            progress(1, L("没有找到可卸载的应用"))
            return []
        }

        // Stable order keeps the progress counter meaningful and the result deterministic.
        urls.sort {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        let total = urls.count
        var apps: [InstalledApp] = []
        apps.reserveCapacity(total)
        var completed = 0
        var nextIndex = 0

        await withTaskGroup(of: (Int, InstalledApp?).self) { group in
            let initial = min(applicationReadConcurrency, total)
            for _ in 0..<initial {
                let index = nextIndex
                let url = urls[index]
                nextIndex += 1
                group.addTask { (index, readApplication(at: url)) }
            }

            while let result = await group.next() {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                completed += 1
                if let app = result.1, includeSystem || !app.isSystem {
                    apps.append(app)
                }
                let fraction = 0.03 + 0.90 * Double(completed) / Double(total)
                progress(min(0.95, fraction), L("正在读取应用… \(completed)/\(total)"))
                if nextIndex < total {
                    let index = nextIndex
                    let url = urls[index]
                    nextIndex += 1
                    group.addTask { (index, readApplication(at: url)) }
                }
            }
        }

        apps.sort {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        if Task.isCancelled {
            progress(1, L("已取消加载，返回 \(apps.count) 个应用"))
        } else {
            progress(1, L("已加载 \(apps.count) 个应用"))
        }
        return apps
    }

    /// Reads one `.app` bundle. Returns nil when the bundle has no readable Info.plist,
    /// so a single broken app never aborts the scan.
    private static func readApplication(at url: URL) -> InstalledApp? {
        let infoURL = url.appendingPathComponent("Contents").appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let info = plist as? [String: Any] else {
            return nil
        }

        let bundleID = trimmed(info["CFBundleIdentifier"] as? String)
        let displayName = trimmed(info["CFBundleDisplayName"] as? String)
        let bundleName = trimmed(info["CFBundleName"] as? String)
        let name = displayName ?? bundleName ?? url.deletingPathExtension().lastPathComponent
        let version = trimmed(info["CFBundleShortVersionString"] as? String)
            ?? trimmed(info["CFBundleVersion"] as? String)
            ?? ""
        let executable = trimmed(info["CFBundleExecutable"] as? String)
        let isSystem = url.path.hasPrefix("/System/")
            || (bundleID?.lowercased().hasPrefix("com.apple.") ?? false)
        let size = FileMeasure.allocatedSizeRecursively(at: url, isCancelled: { Task.isCancelled })
        let lastUsed = lastUsedDate(for: url)

        return InstalledApp(name: name,
                            bundleID: bundleID,
                            version: version,
                            url: url,
                            byteCount: size,
                            lastUsed: lastUsed,
                            isSystem: isSystem,
                            executableName: executable,
                            iconPath: url.path)
    }

    /// Spotlight's last-used date when available; otherwise the file's access time.
    private static func lastUsedDate(for url: URL) -> Date? {
        if let item = NSMetadataItem(url: url),
           let value = item.value(forAttribute: "kMDItemLastUsedDate") as? Date {
            return value
        }
        return (try? url.resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
    }

    // MARK: - Leftovers

    static func findLeftovers(for app: InstalledApp,
                              progress: @escaping @Sendable (Double, String) -> Void) async -> [LeftoverItem] {
        progress(0.02, L("正在检查 \(app.name) 的残留文件…"))

        let candidates = leftoverCandidates(for: app)
        guard !candidates.isEmpty else {
            progress(1, L("没有找到残留文件"))
            return []
        }

        var items: [LeftoverItem] = []
        let total = candidates.count
        for (index, candidate) in candidates.enumerated() {
            if Task.isCancelled { break }
            defer {
                let fraction = 0.05 + 0.90 * Double(index + 1) / Double(total)
                progress(min(0.97, fraction), L("正在检查残留文件… \(index + 1)/\(total)"))
            }

            let url = candidate.url
            guard HomePaths.exists(url) else { continue }
            // Never surface a path the safety gate would refuse to delete.
            guard !SafetyPolicy.isProtected(url) else { continue }

            let size = FileMeasure.allocatedSize(ofItemAt: url)
            items.append(LeftoverItem(name: libraryRelativeName(for: url),
                                      url: url,
                                      byteCount: size,
                                      kind: candidate.kind,
                                      isSelected: true))
        }

        items.sort { $0.byteCount > $1.byteCount }
        let totalBytes = items.reduce(Int64(0)) { $0 + $1.byteCount }
        progress(1, L("找到 \(items.count) 项残留，共 \(Format.bytes(totalBytes))"))
        return items
    }

    /// Candidate leftovers derived from the bundle identifier (preferred) and the
    /// display name. Missing locations are filtered out later, so the list stays small.
    private static func leftoverCandidates(for app: InstalledApp) -> [LeftoverCandidate] {
        let bundleID = trimmed(app.bundleID)
        let appName = trimmed(app.name)
        var result: [LeftoverCandidate] = []
        var seen = Set<String>()

        func add(_ components: [String], _ kind: LeftoverKind) {
            let url = components.reduce(library) { $0.appendingPathComponent($1) }
            guard seen.insert(ToolsSupport.standardizedPath(url)).inserted else { return }
            result.append(LeftoverCandidate(url: url, kind: kind))
        }

        if let bundleID {
            add(["Application Support", bundleID], .applicationSupport)
            add(["Caches", bundleID], .caches)
            add(["Preferences", "\(bundleID).plist"], .preferences)
            add(["Saved Application State", "\(bundleID).savedState"], .savedState)
            add(["Logs", bundleID], .logs)
            add(["Containers", bundleID], .containers)
        }

        if let appName, appName != bundleID {
            add(["Application Support", appName], .applicationSupport)
            add(["Caches", appName], .caches)
            add(["Preferences", "\(appName).plist"], .preferences)
            add(["Saved Application State", "\(appName).savedState"], .savedState)
            add(["Logs", appName], .logs)
            add(["Containers", appName], .containers)
        }

        // System-wide support files and background services installed by the app.
        if let bundleID {
            addSystem(["Application Support", bundleID], .applicationSupport, seen: &seen, result: &result)
            addSystem(["Preferences", "\(bundleID).plist"], .preferences, seen: &seen, result: &result)
        }

        addBackgroundItems(bundleID: bundleID, appName: appName, appURL: app.url,
                           seen: &seen, result: &result)

        return result
    }

    private static func addSystem(_ components: [String], _ kind: LeftoverKind,
                                  seen: inout Set<String>,
                                  result: inout [LeftoverCandidate]) {
        let root = URL(fileURLWithPath: "/Library", isDirectory: true)
        let url = components.reduce(root) { $0.appendingPathComponent($1) }
        guard seen.insert(ToolsSupport.standardizedPath(url)).inserted else { return }
        result.append(LeftoverCandidate(url: url, kind: kind))
    }

    private static func addURL(_ url: URL, _ kind: LeftoverKind,
                               seen: inout Set<String>,
                               result: inout [LeftoverCandidate]) {
        guard seen.insert(ToolsSupport.standardizedPath(url)).inserted else { return }
        result.append(LeftoverCandidate(url: url, kind: kind))
    }

    private static func addBackgroundItems(bundleID: String?,
                                           appName: String?,
                                           appURL: URL,
                                           seen: inout Set<String>,
                                           result: inout [LeftoverCandidate]) {
        let roots = [
            HomePaths.url("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true),
            URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true)
        ]
        let appPath = appURL.path.lowercased()
        let normalizedBundleID = bundleID?.lowercased()
        let normalizedAppName = (appName?.count ?? 0) >= 3 ? appName?.lowercased() : nil

        for root in roots {
            guard let files = try? fm.contentsOfDirectory(at: root,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            for file in files where file.pathExtension.lowercased() == "plist" {
                guard let data = try? Data(contentsOf: file),
                      let plist = try? PropertyListSerialization.propertyList(
                          from: data, options: [], format: nil
                      ) as? [String: Any] else { continue }

                let label = (plist["Label"] as? String)?.lowercased()
                let associated = (plist["AssociatedBundleIdentifiers"] as? [String])?
                    .map { $0.lowercased() } ?? []
                let program = (plist["Program"] as? String)
                    ?? (plist["ProgramArguments"] as? [String])?.first
                let programPath = program?.lowercased()
                let fileName = file.lastPathComponent.lowercased()

                var matched = false
                if let normalizedBundleID {
                    matched = associated.contains(normalizedBundleID)
                        || label == normalizedBundleID
                        || (label?.hasPrefix(normalizedBundleID + ".") ?? false)
                        || fileName.contains(normalizedBundleID)
                }
                if !matched, let normalizedAppName {
                    matched = (label?.contains(normalizedAppName) ?? false)
                        || fileName.contains(normalizedAppName)
                        || (programPath?.contains(normalizedAppName) ?? false)
                }
                if !matched, let programPath, programPath.contains(appPath) {
                    matched = true
                }
                guard matched else { continue }

                addURL(file, .backgroundItem, seen: &seen, result: &result)
                if let program,
                   program.hasPrefix("/Library/PrivilegedHelperTools/"),
                   fm.fileExists(atPath: program) {
                    addURL(URL(fileURLWithPath: program), .backgroundItem,
                           seen: &seen, result: &result)
                }
            }
        }
    }

    private static func libraryRelativeName(for url: URL) -> String {
        let prefix = library.path.hasSuffix("/") ? library.path : library.path + "/"
        if url.path.hasPrefix(prefix) {
            return String(url.path.dropFirst(prefix.count))
        }
        return url.lastPathComponent
    }

    // MARK: - Uninstall

    static func uninstall(app: InstalledApp,
                          leftovers: [LeftoverItem],
                          moveToTrash: Bool,
                          progress: @escaping @Sendable (Double, String) -> Void) async -> CleanReport {
        progress(0.02, L("正在卸载 \(app.name)…"))

        var removedCount = 0
        var freedBytes: Int64 = 0
        var failures: [CleanFailure] = []

        // Only leftovers the user kept selected are removed. The app bundle itself is
        // always the target of this call.
        let selectedLeftovers = leftovers.filter(\.isSelected)
        let totalSteps = 1 + selectedLeftovers.count
        var step = 0

        step += 1
        var appRemoved = false
        do {
            try SafetyPolicy.validate(app.url, context: .appUninstall)
            if ToolsSupport.requiresAdministrator(for: app.url) {
                progress(0.02, L("等待管理员授权…"))
            }
            let measured = ToolsSupport.measureForRemoval(app.url)
            try ToolsSupport.removeItem(at: app.url, moveToTrash: moveToTrash)
            removedCount += 1
            freedBytes += measured
            appRemoved = true
        } catch {
            failures.append(CleanFailure(path: app.url.path,
                                         reason: ToolsSupport.failureReason(error)))
        }
        progress(0.05 + 0.90 * Double(step) / Double(max(1, totalSteps)),
                 L("正在删除应用主程序…"))

        // If the app bundle itself could not be removed (e.g. administrator
        // authorization was cancelled), keep its preferences/caches intact too.
        if appRemoved {
            for leftover in selectedLeftovers {
                if Task.isCancelled { break }
                step += 1
                do {
                    try SafetyPolicy.validate(leftover.url, context: .leftover)
                    let measured = ToolsSupport.measureForRemoval(leftover.url)
                    try ToolsSupport.removeItem(at: leftover.url, moveToTrash: moveToTrash)
                    removedCount += 1
                    freedBytes += measured
                } catch {
                    failures.append(CleanFailure(path: leftover.url.path,
                                                 reason: ToolsSupport.failureReason(error)))
                }
                progress(0.05 + 0.90 * Double(step) / Double(max(1, totalSteps)),
                         L("正在删除残留文件… \(step - 1)/\(selectedLeftovers.count)"))
            }
        }

        let action = moveToTrash ? L("已移到废纸篓") : L("已删除")
        if failures.isEmpty {
            progress(1, L("已卸载 \(app.name)，\(action) \(Format.bytes(freedBytes))"))
        } else {
            progress(1, L("卸载完成，\(failures.count) 项失败"))
        }

        return CleanReport(removedCount: removedCount,
                           freedBytes: freedBytes,
                           failures: failures,
                           completedAt: Date(),
                           movedToTrash: moveToTrash)
    }

    // MARK: - Helpers

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
