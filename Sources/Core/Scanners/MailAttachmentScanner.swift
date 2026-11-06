import Foundation

/// Locally cached mail attachments. Only `MailData/Attachments` directories are
/// touched — the mail database itself is protected by `SafetyPolicy`.
enum MailAttachmentScanner {
    static func items(exclusions: ScanExclusions, isCancelled: () -> Bool) -> [ScanItem] {
        guard !isCancelled() else { return [] }
        let mailRoot = HomePaths.url("Library/Mail")
        guard HomePaths.exists(mailRoot) else { return [] }

        var urls: [URL] = []
        var bytes: Int64 = 0
        var fileCount = 0
        var lastModified: Date?

        for version in HomePaths.children(of: mailRoot) {
            if isCancelled() || Task.isCancelled { return [] }
            guard version.lastPathComponent.hasPrefix("V") else { continue }
            let attachments = version
                .appendingPathComponent("MailData", isDirectory: true)
                .appendingPathComponent("Attachments", isDirectory: true)
            guard HomePaths.exists(attachments), !exclusions.covers(attachments) else { continue }
            let footprint = ScanFileTool.footprint(of: attachments, exclusions: exclusions, isCancelled: isCancelled)
            guard footprint.bytes > 0 else { continue }
            urls.append(attachments)
            bytes += footprint.bytes
            fileCount += footprint.fileCount
            if let date = footprint.lastModified {
                if lastModified == nil || date > lastModified! { lastModified = date }
            }
        }

        guard !urls.isEmpty, bytes > 0 else { return [] }
        let detail = L("共 \(fileCount) 个附件文件，邮件正文与邮箱数据不受影响，附件可按需重新下载")
        return [ScanItem(
            id: "mail:attachments",
            name: L("邮件附件"),
            urls: urls,
            byteCount: bytes,
            kind: .mailAttachment,
            safety: .caution,
            detail: detail,
            modifiedAt: lastModified,
            isSelected: true
        )]
    }
}
