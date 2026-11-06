import Foundation

/// Scans the well-known junk locations. The real implementation is filled in by
/// `SmartScanner` + the per-domain scanners under `Sources/Core/Scanners/`.
enum SmartScanner {
    static func scan(excludedPaths: Set<String>,
                     progress: @escaping @Sendable (ScanProgress) -> Void) async -> SmartScanResult {
        progress(ScanProgress(fraction: 0.2, status: "正在扫描…"))
        try? await Task.sleep(nanoseconds: 200_000_000)
        let disk = DiskInfoProvider.current()
        return SmartScanResult(categories: [],
                               freeBytes: disk.freeBytes,
                               totalBytes: disk.totalBytes,
                               scannedAt: Date(),
                               duration: 0.2)
    }
}
