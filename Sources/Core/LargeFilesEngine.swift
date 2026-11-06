import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Finds large files below the user's common content folders.
enum LargeFilesEngine {
    private static let fm = FileManager.default
    private static let maxResults = 300
    private static let resourceKeys = Set(FileMeasure.resourceKeys)

    private static var defaultRoots: [URL] {
        ["Downloads", "Documents", "Desktop", "Movies", "Pictures", "Music"]
            .map { HomePaths.url($0) }
    }

    // MARK: - Scan

    static func scan(roots: [URL],
                     minSize: Int64,
                     minAgeDays: Int?,
                     progress: @escaping @Sendable (Double, String) -> Void) async -> [LargeFile] {
        progress(0.01, L("正在准备扫描大文件…"))

        let requested = roots.isEmpty ? defaultRoots : roots
        let searchRoots = normalizedRoots(requested)
        guard !searchRoots.isEmpty else {
            progress(1, L("没有可扫描的目录"))
            return []
        }

        let cutoff: Date? = {
            guard let minAgeDays, minAgeDays > 0 else { return nil }
            return Date().addingTimeInterval(-Double(minAgeDays) * 86_400)
        }()

        let libraryRoot = HomePaths.url("Library")
        var files: [LargeFile] = []
        var visited = 0
        var cancelled = false
        var reportedFraction = 0.0

        /// Progress must never move backwards: roots switch quickly while the
        /// visited-entry heuristic catches up, so clamp to the last value.
        func report(_ fraction: Double, _ status: String) {
            let clamped = max(reportedFraction, min(0.99, fraction))
            reportedFraction = clamped
            progress(clamped, status)
        }

        for (rootIndex, root) in searchRoots.enumerated() {
            if Task.isCancelled {
                cancelled = true
                break
            }
            let rootName = root.lastPathComponent.isEmpty ? root.path : root.lastPathComponent
            report(0.03 + 0.90 * Double(rootIndex) / Double(searchRoots.count),
                   L("正在扫描 \(rootName)…"))

            let rootInsideLibrary = ToolsSupport.isInside(root, libraryRoot)
            let rootInsideSystem = ToolsSupport.systemRoots.contains { ToolsSupport.isInside(root, $0) }

            guard let enumerator = fm.enumerator(at: root,
                                                 includingPropertiesForKeys: Array(resourceKeys),
                                                 options: [],
                                                 errorHandler: { _, _ in true }) else { continue }

            while let url = enumerator.nextObject() as? URL {
                visited += 1
                if visited & 0xFF == 0 {
                    if Task.isCancelled {
                        cancelled = true
                        break
                    }
                    let fraction = 0.03 + 0.90 * Double(visited) / Double(visited + 8_000)
                    report(min(0.95, fraction), L("正在扫描…已检查 \(visited) 项"))
                }

                guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
                if values.isSymbolicLink == true { continue }

                if values.isDirectory == true {
                    if shouldPruneDirectory(url,
                                            rootInsideLibrary: rootInsideLibrary,
                                            rootInsideSystem: rootInsideSystem) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard values.isRegularFile == true else { continue }
                let byteCount = FileMeasure.byteCount(from: values)
                guard byteCount >= minSize else { continue }

                let modifiedAt = values.contentModificationDate ?? .distantPast
                if let cutoff, modifiedAt > cutoff { continue }

                files.append(LargeFile(url: url,
                                       byteCount: byteCount,
                                       modifiedAt: modifiedAt,
                                       kind: kind(for: url),
                                       isSelected: false))

                // Bound memory/time on pathological trees; only the top results matter.
                if files.count >= maxResults * 4 {
                    files.sort { $0.byteCount > $1.byteCount }
                    if files.count > maxResults {
                        files.removeLast(files.count - maxResults)
                    }
                }
            }

            if cancelled { break }
        }

        files.sort { $0.byteCount > $1.byteCount }
        if files.count > maxResults {
            files.removeLast(files.count - maxResults)
        }

        if cancelled {
            progress(1, L("扫描已取消，返回 \(files.count) 个大文件"))
        } else {
            progress(1, L("扫描完成，找到 \(files.count) 个大文件"))
        }
        return files
    }

    /// Standardizes, de-duplicates and removes roots that are already covered by
    /// another (shallower) root so nested roots never yield duplicate files.
    private static func normalizedRoots(_ roots: [URL]) -> [URL] {
        var unique: [URL] = []
        var seen = Set<String>()
        for root in roots {
            let url = ToolsSupport.standardizedURL(root)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  seen.insert(url.path).inserted else { continue }
            unique.append(url)
        }
        unique.sort { $0.path.count < $1.path.count }

        var topRoots: [URL] = []
        for root in unique {
            if topRoots.contains(where: { ToolsSupport.isInside(root, $0) }) { continue }
            topRoots.append(root)
        }
        return topRoots
    }

    /// Package-like directories whose internals must not be listed as standalone
    /// files: trashing a file inside an app bundle / photo library would corrupt it.
    private static let prunedPackageExtensions: Set<String> = [
        "app", "appex", "bundle", "framework", "plugin", "kext",
        "photoslibrary", "fcpbundle", "logicx", "sparsebundle",
        "xcodeproj", "xcworkspace", "playground"
    ]

    private static func shouldPruneDirectory(_ url: URL,
                                            rootInsideLibrary: Bool,
                                            rootInsideSystem: Bool) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return true }
        if ToolsSupport.prunedDirectoryNames.contains(name) { return true }
        if prunedPackageExtensions.contains(url.pathExtension.lowercased()) { return true }
        if !rootInsideLibrary && ToolsSupport.isInside(url, HomePaths.url("Library")) {
            return true
        }
        if !rootInsideSystem && ToolsSupport.systemRoots.contains(where: { ToolsSupport.isInside(url, $0) }) {
            return true
        }
        return false
    }

    // MARK: - Kind mapping

    private static let kindByExtension: [String: LargeFileKind] = {
        let video = ["mp4", "mov", "m4v", "mkv", "avi", "wmv", "flv", "webm", "mpg", "mpeg", "3gp", "ts", "m2ts"]
        let image = ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp", "raw", "dng", "psd"]
        let archive = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "tbz", "zst", "cab", "xip", "pkg"]
        let diskImage = ["dmg", "iso", "img", "sparseimage", "sparsebundle", "vhd", "vmdk"]
        let audio = ["mp3", "m4a", "wav", "aiff", "aif", "flac", "aac", "ogg", "wma"]
        let document = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "txt", "rtf", "csv", "md", "epub"]
        let code = ["swift", "m", "mm", "h", "c", "cc", "cpp", "hpp", "js", "ts", "jsx", "tsx", "java", "py", "rb", "go", "rs", "kt", "sh", "json", "xml", "html", "css", "sql", "db", "ipa", "apk"]

        var map: [String: LargeFileKind] = [:]
        for ext in video { map[ext] = .video }
        for ext in image { map[ext] = .image }
        for ext in archive { map[ext] = .archive }
        for ext in diskImage { map[ext] = .diskImage }
        for ext in audio { map[ext] = .audio }
        for ext in document { map[ext] = .document }
        for ext in code { map[ext] = .code }
        return map
    }()

    private static func kind(for url: URL) -> LargeFileKind {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return .other }
        if let kind = kindByExtension[ext] { return kind }
        #if canImport(UniformTypeIdentifiers)
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .archive) { return .archive }
            if type.conforms(to: .audio) { return .audio }
            if type.conforms(to: .diskImage) { return .diskImage }
            if type.conforms(to: .sourceCode) { return .code }
            if type.conforms(to: .pdf) || type.conforms(to: .text) { return .document }
        }
        #endif
        return .other
    }

    // MARK: - Trash

    static func trash(files: [LargeFile],
                      progress: @escaping @Sendable (Double, String) -> Void) async -> CleanReport {
        progress(0.01, L("正在移到废纸篓…"))

        // Only user-selected rows are removed. Callers may pass the entire scan
        // result; unselected entries are ignored (never delete what was deselected).
        let selected = files.filter(\.isSelected)
        guard !selected.isEmpty else {
            progress(1, L("没有选择要删除的文件"))
            return CleanReport(removedCount: 0,
                               freedBytes: 0,
                               failures: [],
                               completedAt: Date(),
                               movedToTrash: true)
        }

        var removedCount = 0
        var freedBytes: Int64 = 0
        var failures: [CleanFailure] = []
        var cancelled = false

        for (index, file) in selected.enumerated() {
            if Task.isCancelled {
                cancelled = true
                break
            }
            do {
                try SafetyPolicy.validate(file.url, context: .largeFile)
                let measured = ToolsSupport.measureForRemoval(file.url)
                try ToolsSupport.removeItem(at: file.url, moveToTrash: true)
                removedCount += 1
                freedBytes += measured > 0 ? measured : file.byteCount
            } catch {
                failures.append(CleanFailure(path: file.url.path,
                                             reason: ToolsSupport.failureReason(error)))
            }
            progress(0.02 + 0.96 * Double(index + 1) / Double(selected.count),
                     L("正在移到废纸篓… \(index + 1)/\(selected.count)"))
        }

        if cancelled {
            progress(1, L("已取消，移入废纸篓 \(removedCount) 项"))
        } else if failures.isEmpty {
            progress(1, L("已移入废纸篓 \(removedCount) 项，释放 \(Format.bytes(freedBytes))"))
        } else {
            progress(1, L("完成，移入废纸篓 \(removedCount) 项，\(failures.count) 项失败"))
        }

        return CleanReport(removedCount: removedCount,
                           freedBytes: freedBytes,
                           failures: failures,
                           completedAt: Date(),
                           movedToTrash: true)
    }
}
