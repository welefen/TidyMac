import Foundation

/// Small helpers shared by the tool engines (uninstaller, large files, space lens).
/// Foundation-only: this file is also compiled into the headless CLI target.
enum ToolsSupport {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let fileManager = FileManager.default

    /// Directory names that are pruned while walking user content for large files.
    /// Hidden names (leading ".") are pruned as well.
    static let prunedDirectoryNames: Set<String> = [
        "node_modules",
        ".git",
        ".svn",
        ".hg",
        ".Trash",
        ".Trashes",
        ".Spotlight-V100",
        ".fseventsd",
        ".DocumentRevisions-V100",
        ".TemporaryItems"
    ]

    /// Root locations that never contain user content worth listing.
    static let systemRoots: [URL] = [
        "/System", "/Library", "/usr", "/bin", "/sbin", "/etc", "/private",
        "/opt", "/cores", "/Applications", "/Volumes"
    ].map { URL(fileURLWithPath: $0, isDirectory: true) }

    static func standardizedPath(_ url: URL) -> String {
        (url.path as NSString).standardizingPath
    }

    static func standardizedURL(_ url: URL) -> URL {
        URL(fileURLWithPath: standardizedPath(url))
    }

    static func isInside(_ url: URL, _ root: URL) -> Bool {
        let path = standardizedPath(url)
        let rootPath = standardizedPath(root)
        if path == rootPath { return true }
        if rootPath == "/" { return path.hasPrefix("/") }
        return path.hasPrefix(rootPath + "/")
    }

    static func removeItem(at url: URL, moveToTrash: Bool) throws {
        if moveToTrash {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } else {
            try fileManager.removeItem(at: url)
        }
    }

    static func failureReason(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }

    /// Size used for "freed bytes" accounting. Measured right before removal.
    static func measureForRemoval(_ url: URL) -> Int64 {
        FileMeasure.allocatedSize(ofItemAt: url)
    }
}
