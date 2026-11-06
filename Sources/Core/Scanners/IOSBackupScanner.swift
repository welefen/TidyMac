import Foundation

/// iOS device backups. These are user data: always reported, never selected by
/// default, and cleaned only when the user explicitly opts in.
enum IOSBackupScanner {
    private static let minimumBytes: Int64 = 1_000_000

    static func items(exclusions: ScanExclusions, isCancelled: () -> Bool) -> [ScanItem] {
        guard !isCancelled() else { return [] }
        let root = HomePaths.url("Library/Application Support/MobileSync/Backup")
        guard HomePaths.exists(root) else { return [] }

        var items: [ScanItem] = []
        for child in ScanFileTool.children(of: root, exclusions: exclusions) {
            if isCancelled() || Task.isCancelled { break }
            guard ScanFileTool.isDirectory(child) else { continue }
            let footprint = ScanFileTool.footprint(of: child, exclusions: exclusions, isCancelled: isCancelled)
            guard footprint.bytes >= minimumBytes else { continue }
            let info = backupInfo(child)
            let deviceName = (info?["Device Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastBackup = info?["Last Backup Date"] as? Date
            let name = (deviceName?.isEmpty == false ? deviceName! : ScanFileTool.name(of: child))
            var detail = L("iOS 设备备份，删除后需要重新连接设备备份")
            if let lastBackup {
                detail = L("\(name) · 最后备份 \(Format.date(lastBackup)) · 删除后需要重新备份")
            } else if let deviceName, !deviceName.isEmpty {
                detail = L("\(deviceName) 的备份，删除后需要重新备份")
            }
            items.append(ScanItem(
                id: "ios-backup:" + child.path,
                name: name,
                urls: [child],
                byteCount: footprint.bytes,
                kind: .iosBackup,
                safety: .risky,
                detail: detail,
                modifiedAt: lastBackup ?? footprint.lastModified,
                isSelected: false
            ))
        }
        return items
    }

    /// Best-effort read of the backup metadata; failures are ignored.
    private static func backupInfo(_ backup: URL) -> [String: Any]? {
        let plist = backup.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plist) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil))
            as? [String: Any]
    }
}
