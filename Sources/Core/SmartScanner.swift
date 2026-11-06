import Foundation

/// Scans the well-known junk locations of the current user and returns the
/// results grouped into the categories the UI already understands.
///
/// Safety rules:
/// * Only paths below the current user's home (plus nothing else) are scanned.
/// * `excludedPaths` and any path below them are skipped entirely; while a
///   directory is measured, excluded subtrees are pruned from the byte count.
/// * Unreadable directories are skipped silently — scanning never throws.
enum SmartScanner {
    private struct Domain: Sendable {
        let categoryID: String
        let title: String
        let subtitle: String
        let symbol: String
        let tone: AccentTone
        let group: CleanupGroup
        let load: @Sendable (ScanExclusions) async -> [ScanItem]
    }

    /// Categories are scanned in parallel, but at most this many at a time to
    /// keep disk IO on spinning disks and SMB mounts sane.
    private static let concurrencyLimit = 5

    private static var domains: [Domain] {
        [
            Domain(categoryID: "system-cache",
                   title: L("用户缓存"),
                   subtitle: L("应用运行时生成的临时数据，可安全重建"),
                   symbol: "shippingbox.fill",
                   tone: .mint,
                   group: .systemJunk,
                   load: { exclusions in
                       UserCacheScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   }),
            Domain(categoryID: "logs",
                   title: L("日志与崩溃报告"),
                   subtitle: L("诊断日志与旧崩溃记录"),
                   symbol: "doc.text.magnifyingglass",
                   tone: .blue,
                   group: .systemJunk,
                   load: { exclusions in
                       LogScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   }),
            Domain(categoryID: "xcode",
                   title: L("Xcode 构建缓存"),
                   subtitle: L("DerivedData、设备支持与模拟器缓存"),
                   symbol: "hammer.fill",
                   tone: .purple,
                   group: .developerJunk,
                   load: { exclusions in
                       XcodeScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   }),
            Domain(categoryID: "dev-packages",
                   title: L("包管理器缓存"),
                   subtitle: L("npm、Homebrew、pip 等下载缓存"),
                   symbol: "shippingbox.and.arrow.backward.fill",
                   tone: .teal,
                   group: .developerJunk,
                   load: { exclusions in
                       PackageCacheScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   }),
            Domain(categoryID: "browser",
                   title: L("浏览器数据"),
                   subtitle: L("网页缓存与旧版本资源，建议先退出浏览器"),
                   symbol: "safari.fill",
                   tone: .blue,
                   group: .browserJunk,
                   load: { exclusions in
                       BrowserCacheScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   }),
            Domain(categoryID: "mail",
                   title: L("邮件附件"),
                   subtitle: L("已下载至本地的附件副本，邮件本身不受影响"),
                   symbol: "envelope.fill",
                   tone: .pink,
                   group: .mailAttachments,
                   load: { exclusions in
                       MailAttachmentScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   }),
            Domain(categoryID: "ios-backups",
                   title: L("iOS 设备备份"),
                   subtitle: L("旧设备备份，删除后需重新备份"),
                   symbol: "iphone.gen3",
                   tone: .yellow,
                   group: .iosBackups,
                   load: { exclusions in
                       IOSBackupScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   }),
            Domain(categoryID: "trash",
                   title: L("废纸篓"),
                   subtitle: L("已删除但仍占用磁盘空间的项目"),
                   symbol: "trash.fill",
                   tone: .orange,
                   group: .trash,
                   load: { exclusions in
                       TrashScanner.items(exclusions: exclusions, isCancelled: { Task.isCancelled })
                   })
        ]
    }

    static func scan(excludedPaths: Set<String>,
                     progress: @escaping @Sendable (ScanProgress) -> Void) async -> SmartScanResult {
        let startedAt = Date()
        let exclusions = ScanExclusions(excludedPaths)
        let domains = Self.domains
        var collected: [Int: [ScanItem]] = [:]

        progress(ScanProgress(fraction: 0.05,
                              status: L("正在准备扫描…"),
                              detail: L("检查可访问的缓存与日志位置")))

        guard !Task.isCancelled, !domains.isEmpty else {
            return makeResult(categories: [], startedAt: startedAt)
        }

        await withTaskGroup(of: (Int, [ScanItem]).self) { group in
            var next = 0
            let initial = min(concurrencyLimit, domains.count)

            while next < initial {
                let index = next
                let domain = domains[index]
                progress(ScanProgress(fraction: completedFraction(collected.count, total: domains.count),
                                      status: L("正在扫描\(domain.title)…"),
                                      detail: domain.subtitle))
                group.addTask {
                    let items = await domain.load(exclusions)
                    return (index, items)
                }
                next += 1
            }

            while let (index, items) = await group.next() {
                collected[index] = items
                let fraction = completedFraction(collected.count, total: domains.count)
                progress(ScanProgress(fraction: fraction,
                                      status: L("已扫描\(domains[index].title)"),
                                      detail: items.isEmpty ? L("未发现可清理项目") : L("发现 \(items.count) 项")))

                if Task.isCancelled {
                    group.cancelAll()
                    continue
                }
                if next < domains.count {
                    let upcomingIndex = next
                    let domain = domains[upcomingIndex]
                    progress(ScanProgress(fraction: fraction,
                                          status: L("正在扫描\(domain.title)…"),
                                          detail: domain.subtitle))
                    group.addTask {
                        let items = await domain.load(exclusions)
                        return (upcomingIndex, items)
                    }
                    next += 1
                }
            }
        }

        if Task.isCancelled {
            return makeResult(categories: [], startedAt: startedAt)
        }
        progress(ScanProgress(fraction: 0.95, status: L("正在整理扫描结果…")))

        let categories = domains.enumerated().compactMap { index, domain -> ScanCategory? in
            guard let items = collected[index], !items.isEmpty else { return nil }
            return ScanCategory(id: domain.categoryID,
                                title: domain.title,
                                subtitle: domain.subtitle,
                                symbol: domain.symbol,
                                tone: domain.tone,
                                group: domain.group,
                                items: sortedItems(items))
        }
        return makeResult(categories: categories, startedAt: startedAt)
    }

    private static func completedFraction(_ completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0.95 }
        let ratio = min(1, max(0, Double(completed) / Double(total)))
        return 0.05 + 0.9 * ratio
    }

    private static func makeResult(categories: [ScanCategory], startedAt: Date) -> SmartScanResult {
        let disk = DiskInfoProvider.current()
        return SmartScanResult(categories: categories,
                               freeBytes: disk.freeBytes,
                               totalBytes: disk.totalBytes,
                               scannedAt: Date(),
                               duration: Date().timeIntervalSince(startedAt))
    }

    /// Largest first; the synthetic L("其他…") bucket always stays at the end.
    private static func sortedItems(_ items: [ScanItem]) -> [ScanItem] {
        var sorted: [ScanItem] = []
        var aggregate: [ScanItem] = []
        for item in items {
            if item.id.hasSuffix(":other") {
                aggregate.append(item)
            } else {
                sorted.append(item)
            }
        }
        sorted.sort { $0.byteCount > $1.byteCount }
        return sorted + aggregate
    }
}
