import Foundation

enum RemovalContext {
    /// Smart-scan junk items (caches, logs, trash, developer junk...).
    case junk
    /// Files selected in Large & Old Files.
    case largeFile
    /// An application bundle being uninstalled.
    case appUninstall
    /// Orphaned support files belonging to an uninstalled app.
    case leftover
}

enum SafetyError: LocalizedError, Equatable {
    case rootPath
    case protectedPath(String)
    case outsideAllowedScope(String)
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .rootPath:
            return L("拒绝操作：不能删除磁盘根目录或用户主目录。")
        case .protectedPath(let path):
            return L("受保护路径，已跳过：\(HomePaths.relativePath(URL(fileURLWithPath: path)))")
        case .outsideAllowedScope(let path):
            return L("超出允许的清理范围：\(HomePaths.relativePath(URL(fileURLWithPath: path)))")
        case .invalidPath:
            return L("路径无效。")
        }
    }
}

/// Central safety gate. Every destructive operation must pass through `validate`.
/// The policy is intentionally conservative: when in doubt, refuse.
enum SafetyPolicy {
    private static let fm = FileManager.default
    private static let home = HomePaths.home

    // MARK: Protected paths

    static var protectedRoots: [String] {
        [
            "/",
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/etc",
            "/var",
            "/private",
            "/Library",
            "/Applications",
            "/opt",
            "/cores",
            "/Volumes",
            "/Users",
            home.path,
            home.appendingPathComponent(".ssh").path,
            home.appendingPathComponent(".gnupg").path,
            home.appendingPathComponent(".config").path,
            home.appendingPathComponent("Library/Keychains").path,
            home.appendingPathComponent("Library/Messages").path,
            home.appendingPathComponent("Library/Mail").path,
            home.appendingPathComponent("Library/Safari").path,
            home.appendingPathComponent("Library/Cookies").path,
            home.appendingPathComponent("Library/Accounts").path,
            home.appendingPathComponent("Library/Calendars").path,
            home.appendingPathComponent("Library/Application Support/AddressBook").path,
            home.appendingPathComponent("Library/Application Support/com.apple.TCC").path,
            home.appendingPathComponent("Library/Group Containers").path,
            home.appendingPathComponent("Library/Containers").path,
            home.appendingPathComponent("Library/Mobile Documents").path,
            home.appendingPathComponent("Library/CloudStorage").path,
            home.appendingPathComponent("Pictures/Photos Library.photoslibrary").path,
            home.appendingPathComponent(".Trash").path
        ]
    }

    /// Paths that are protected in general but can be cleaned inside a specific context.
    private static var mailAttachmentsMarker: String {
        home.path + "/Library/Mail/"
    }
    private static let mailAttachmentsSubpath = "/MailData/Attachments"

    static func isProtected(_ path: String) -> Bool {
        let p = normalized(path)
        if p == "/" || p == home.path { return true }

        // Temporary folders live under /var (which is protected). Individual
        // selftest / helper files inside them must remain removable. The temp
        // root itself stays protected.
        let tempRoot = normalized(NSTemporaryDirectory())
        if !tempRoot.isEmpty, p != tempRoot {
            if isDescendant(p, of: tempRoot) { return false }
            if tempRoot.hasPrefix("/var/"), isDescendant(p, of: "/private" + tempRoot) { return false }
        }
        if isDescendant(p, of: "/tmp"), p != "/tmp" { return false }

        for root in protectedRoots {
            // "/" matches every absolute path. The root itself is already
            // rejected above, so it must not be treated as a protected subtree.
            if root == "/" { continue }
            // The home folder is protected, but its descendants are governed by
            // the more specific entries below and by the per-context scope checks.
            if root == home.path { continue }
            // `/Users` protects other users' homes, not the current user's files.
            if root == "/Users", isDescendant(p, of: home.path) { continue }
            if isDescendant(p, of: root) {
                // Special-case mail attachments: they are junk, not the mail database.
                if root == home.appendingPathComponent("Library/Mail").path,
                   p.hasPrefix(mailAttachmentsMarker),
                   p.contains(mailAttachmentsSubpath) {
                    return false
                }
                // Trash contents may be emptied by the dedicated trash flow.
                if root == home.appendingPathComponent(".Trash").path, p != root {
                    return false
                }
                return true
            }
        }
        return false
    }

    static func isProtected(_ url: URL) -> Bool {
        isProtected(url.path)
    }

    // MARK: Allowed roots per context

    static var junkAllowedRoots: [String] {
        [
            home.appendingPathComponent("Library/Caches").path,
            home.appendingPathComponent("Library/Logs").path,
            home.appendingPathComponent("Library/Saved Application State").path,
            home.appendingPathComponent("Library/Developer").path,
            home.appendingPathComponent("Library/Application Support/CrashReporter").path,
            home.appendingPathComponent("Library/Application Support/MobileSync/Backup").path,
            home.appendingPathComponent("Library/Mail").path,
            home.appendingPathComponent("Downloads").path,
            home.appendingPathComponent("Library/pnpm").path,
            home.appendingPathComponent(".npm").path,
            home.appendingPathComponent(".gradle").path,
            home.appendingPathComponent(".cargo").path,
            home.appendingPathComponent(".Trash").path,
            NSTemporaryDirectory(),
            "/tmp"
        ].map(normalized)
    }

    static func isInsideJunkScope(_ path: String) -> Bool {
        let p = normalized(path)
        return junkAllowedRoots.contains { isDescendant(p, of: $0) }
    }

    // MARK: Validation

    static func validate(_ url: URL, context: RemovalContext) throws {
        let path = normalized(url.path)
        guard !path.isEmpty, path != ".", path != "/" else { throw SafetyError.rootPath }
        guard path != normalized(home.path) else { throw SafetyError.rootPath }

        let isApplicationsBundle = isDescendant(path, of: "/Applications") && path.hasSuffix(".app")
        if isProtected(path) && !(context == .appUninstall && isApplicationsBundle) {
            throw SafetyError.protectedPath(path)
        }

        switch context {
        case .junk:
            guard isInsideJunkScope(path) else {
                throw SafetyError.outsideAllowedScope(path)
            }
        case .largeFile:
            let insideHome = isDescendant(path, of: normalized(home.path))
            let insideTemp = isDescendant(path, of: normalized(NSTemporaryDirectory()))
                || isDescendant(path, of: "/tmp")
            guard insideHome || insideTemp else {
                throw SafetyError.outsideAllowedScope(path)
            }
        case .leftover:
            guard isDescendant(path, of: normalized(home.path)) else {
                throw SafetyError.outsideAllowedScope(path)
            }
        case .appUninstall:
            let insideApplications = isDescendant(path, of: "/Applications")
                || isDescendant(path, of: normalized(home.appendingPathComponent("Applications").path))
            guard insideApplications, path.hasSuffix(".app") else {
                throw SafetyError.outsideAllowedScope(path)
            }
        }
    }

    static func isSafeToRemove(_ url: URL, context: RemovalContext) -> Bool {
        (try? validate(url, context: context)) != nil
    }

    // MARK: Helpers

    static func normalized(_ path: String) -> String {
        var p = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        p = (p as NSString).standardizingPath
        return p
    }

    static func isDescendant(_ path: String, of root: String) -> Bool {
        let p = normalized(path)
        let r = normalized(root)
        if p == r { return true }
        if r == "/" { return p.hasPrefix("/") }
        return p.hasPrefix(r + "/")
    }

    /// A short explanation for the UI of why a path is off-limits.
    static func protectionReason(for url: URL) -> String {
        do {
            try validate(url, context: .largeFile)
            return ""
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? L("受保护路径")
        }
    }
}
