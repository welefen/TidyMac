import Foundation

enum HomePaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let fileManager = FileManager.default

    static func url(_ relative: String) -> URL {
        home.appendingPathComponent(relative)
    }

    static func exists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    static func isReadable(_ url: URL) -> Bool {
        fileManager.isReadableFile(atPath: url.path)
    }

    static func children(of url: URL, includingHidden: Bool = true) -> [URL] {
        var options: FileManager.DirectoryEnumerationOptions = []
        if !includingHidden { options.insert(.skipsHiddenFiles) }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: FileMeasure.resourceKeys,
            options: options
        ) else { return [] }
        return urls
    }

    static func relativePath(_ url: URL) -> String {
        let homePrefix = home.path.hasSuffix("/") ? home.path : home.path + "/"
        if url.path.hasPrefix(homePrefix) {
            return "~/" + String(url.path.dropFirst(homePrefix.count))
        }
        return url.path
    }

    /// Expands a user supplied path string ("~/Downloads/x" or "/tmp/x").
    static func expand(_ raw: String) -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "~" { return home }
        if trimmed.hasPrefix("~/") {
            return home.appendingPathComponent(String(trimmed.dropFirst(2)))
        }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
    }
}

enum FileMeasure {
    static let resourceKeys: [URLResourceKey] = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .totalFileSizeKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .creationDateKey
    ]

    private static let keySet = Set(resourceKeys)

    /// Allocated size on disk in bytes (falls back to logical size).
    static func allocatedSize(ofItemAt url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: keySet) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory == true {
            return allocatedSizeRecursively(at: url)
        }
        return byteCount(from: values)
    }

    /// Recursively adds up the allocated size of every regular file beneath `url`.
    /// Symlinks are not followed and unreadable entries are skipped.
    static func allocatedSizeRecursively(at url: URL) -> Int64 {
        allocatedSizeRecursively(at: url, isCancelled: { false })
    }

    static func allocatedSizeRecursively(at url: URL, isCancelled: () -> Bool) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: keySet) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isRegularFile == true { return byteCount(from: values) }
        guard values.isDirectory == true else { return byteCount(from: values) }

        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let child as URL in enumerator {
            if isCancelled() { break }
            guard let childValues = try? child.resourceValues(forKeys: keySet) else { continue }
            if childValues.isSymbolicLink == true { continue }
            if childValues.isRegularFile == true {
                total += byteCount(from: childValues)
            }
        }
        return total
    }

    static func allocatedSize(of urls: [URL]) -> Int64 {
        urls.reduce(0) { $0 + allocatedSize(ofItemAt: $1) }
    }

    static func byteCount(from values: URLResourceValues) -> Int64 {
        if let total = values.totalFileAllocatedSize, total > 0 { return Int64(total) }
        if let allocated = values.fileAllocatedSize, allocated > 0 { return Int64(allocated) }
        if let total = values.totalFileSize, total > 0 { return Int64(total) }
        if let logical = values.fileSize, logical > 0 { return Int64(logical) }
        return 0
    }

    static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// Directory entries with their immediately computed size. Used by Space Lens.
    static func directChildrenWithSizes(of directory: URL, isCancelled: () -> Bool = { false }) -> [SpaceNode] {
        let children = HomePaths.children(of: directory)
        var nodes: [SpaceNode] = []
        for child in children {
            if isCancelled() { break }
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let size = allocatedSize(ofItemAt: child)
            nodes.append(SpaceNode(
                name: child.lastPathComponent,
                url: child,
                byteCount: size,
                isDirectory: isDir,
                childCount: 0,
                children: []
            ))
        }
        return nodes
    }
}
