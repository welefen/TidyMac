import Foundation

/// The user's trash. Kept as a single item: the cleaner empties the contents of
/// `~/.Trash` child by child and never removes the trash folder itself.
enum TrashScanner {
    static func items(exclusions: ScanExclusions, isCancelled: () -> Bool) -> [ScanItem] {
        guard !isCancelled() else { return [] }
        let trash = HomePaths.url(".Trash")
        guard HomePaths.exists(trash) else { return [] }

        let children = HomePaths.children(of: trash)
        let footprint = ScanFileTool.footprint(of: trash, exclusions: exclusions, isCancelled: isCancelled)
        guard !children.isEmpty || footprint.bytes > 0 else { return [] }

        return [ScanItem(
            id: "trash:root",
            name: L("废纸篓"),
            urls: [trash],
            byteCount: footprint.bytes,
            kind: .trash,
            safety: .safe,
            detail: L("包含 \(children.count) 个项目，清空后将无法恢复"),
            modifiedAt: footprint.lastModified,
            isSelected: true
        )]
    }
}
