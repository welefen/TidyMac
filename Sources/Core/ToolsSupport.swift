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
        // Never let FileManager start its own authorization UI for root-owned
        // app bundles. Doing so and then falling back to our helper can create
        // two competing prompts and leave the UI stuck at 2%.
        if requiresAdministrator(for: url) {
            try removeRootOwnedAppWithFinder(url)
            return
        }
        do {
            if moveToTrash {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            } else {
                try fileManager.removeItem(at: url)
            }
        } catch {
            let nsError = error as NSError
            let permissionDenied = (nsError.domain == NSCocoaErrorDomain
                && [NSFileWriteNoPermissionError, NSFileReadNoPermissionError,
                    NSFileWriteVolumeReadOnlyError].contains(nsError.code))
                || (nsError.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(nsError.code))
            guard permissionDenied, requiresAdministrator(for: url) else { throw error }
            // macOS may have moved the item itself (then returned an error) or
            // another process may have raced us. Never ask for authorization
            // for a path that no longer exists.
            if !fileManager.fileExists(atPath: url.path) { return }
            do {
                try removeWithAdministrator(url, moveToTrash: moveToTrash)
            } catch {
                // If the privileged move completed but a later chown failed,
                // treat the app as removed instead of leaving a stuck failure.
                if !fileManager.fileExists(atPath: url.path) { return }
                throw error
            }
        }
    }

    /// App Store and pkg-installed applications are owned by root. They cannot
    /// be moved by the current user, so the only way to uninstall them without
    /// using Finder is to ask macOS for administrator authorization.
    static func requiresAdministrator(for url: URL) -> Bool {
        let path = standardizedPath(url)
        guard pathExtensionIsApp(path) else { return false }
        guard path.hasPrefix("/Applications/")
                || path.hasPrefix(home.appendingPathComponent("Applications").path + "/") else {
            return false
        }
        let owner = (try? fileManager.attributesOfItem(atPath: path))?[.ownerAccountName] as? String
        return owner == "root"
    }

    private static func pathExtensionIsApp(_ path: String) -> Bool {
        (path as NSString).pathExtension.lowercased() == "app"
    }

    /// Finder owns the privileged move-to-Trash flow for root-owned App Store
    /// applications and presents the administrator dialog reliably. Driving
    /// Finder avoids the invisible `do shell script ... with administrator
    /// privileges` prompt that left the uninstall progress stuck.
    private static func removeRootOwnedAppWithFinder(_ url: URL) throws {
        let path = standardizedURL(url).path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            activate
            delete POSIX file "\(path)"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let stderr = Pipe()
        process.standardError = stderr
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(180)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if process.isRunning {
                process.terminate()
                throw PrivilegedRemovalError.failed(L("等待 Finder 授权超时"))
            }
        } catch let error as PrivilegedRemovalError {
            throw error
        } catch {
            throw PrivilegedRemovalError.failed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fileManager.fileExists(atPath: path) { return }
            if message.localizedCaseInsensitiveContains("cancel")
                || message.contains("-128") {
                throw PrivilegedRemovalError.cancelled
            }
            throw PrivilegedRemovalError.failed(message.isEmpty ? L("Finder 未能移动应用") : message)
        }
    }

    private static func removeWithAdministrator(_ url: URL, moveToTrash: Bool) throws {
        let source = standardizedURL(url)
        if moveToTrash {
            let trash = home.appendingPathComponent(".Trash", isDirectory: true)
            try? fileManager.createDirectory(at: trash, withIntermediateDirectories: true)
            var destination = trash.appendingPathComponent(source.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                let stamp = ISO8601DateFormatter().string(from: Date())
                    .replacingOccurrences(of: ":", with: "-")
                let base = source.deletingPathExtension().lastPathComponent
                destination = trash.appendingPathComponent("\(base)-\(stamp).app")
            }
            let script = """
            on run argv
                set srcPath to item 1 of argv
                set dstPath to item 2 of argv
                set ownerSpec to item 3 of argv
                do shell script "/bin/mv " & quoted form of srcPath & " " & quoted form of dstPath & " && /usr/sbin/chown -R " & ownerSpec & " " & quoted form of dstPath with administrator privileges
            end run
            """
            try runAppleScript(script,
                               arguments: [source.path, destination.path, "\(getuid()):\(getgid())"])
        } else {
            let script = """
            on run argv
                set srcPath to item 1 of argv
                do shell script "/bin/rm -rf " & quoted form of srcPath with administrator privileges
            end run
            """
            try runAppleScript(script, arguments: [source.path])
        }
    }

    private static func runAppleScript(_ script: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script] + arguments
        let stderr = Pipe()
        process.standardError = stderr
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(180)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if process.isRunning {
                process.terminate()
                throw PrivilegedRemovalError.failed(L("管理员授权超时"))
            }
        } catch let error as PrivilegedRemovalError {
            throw error
        } catch {
            throw PrivilegedRemovalError.failed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if message.localizedCaseInsensitiveContains("cancel")
                || message.contains("-128") {
                throw PrivilegedRemovalError.cancelled
            }
            throw PrivilegedRemovalError.failed(message.isEmpty ? L("管理员授权失败") : message)
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


enum PrivilegedRemovalError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return L("需要管理员授权才能卸载 App Store 应用")
        case .failed(let message):
            return L("管理员授权失败：%@", message)
        }
    }
}
