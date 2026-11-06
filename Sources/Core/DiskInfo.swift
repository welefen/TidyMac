import Foundation

enum DiskInfoProvider {
    static func current(for url: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskInfo {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return .empty
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        return DiskInfo(totalBytes: total,
                        freeBytes: max(0, free),
                        volumeName: values.volumeName ?? "Macintosh HD")
    }
}

enum FullDiskAccess {
    /// Best-effort detection. A false negative is acceptable; the UI only uses this
    /// to show a helpful hint, never to block cleaning.
    static func hasAccess() -> Bool {
        let probes = [
            HomePaths.url("Library/Safari/History.db"),
            HomePaths.url("Library/Mail"),
            HomePaths.url("Library/Application Support/com.apple.TCC/TCC.db")
        ]
        for probe in probes where HomePaths.exists(probe) {
            if HomePaths.isReadable(probe) { return true }
        }
        // If none of the probes exist we cannot tell.
        return !probes.contains(where: HomePaths.exists)
    }

    static func openPrivacySettings() {
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
    }
}
