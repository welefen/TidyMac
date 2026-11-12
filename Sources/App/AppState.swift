import Foundation
import Combine
import SwiftUI

enum ScanPhase: String, Equatable {
    case idle
    case scanning
    case results
    case cleaning
    case finished
}

struct LaunchOptions {
    var isDemo = false
    var autoScan = false
    var page: AppPage?
    var demoState: String?

    static var current: LaunchOptions {
        var options = LaunchOptions()
        let args = CommandLine.arguments
        let environment = ProcessInfo.processInfo.environment

        options.isDemo = args.contains("--demo") || environment["TIDYMAC_DEMO"] == "1"
        options.autoScan = args.contains("--scan") || environment["TIDYMAC_SCAN"] == "1"

        let rawPage: String? = {
            if let value = environment["TIDYMAC_PAGE"] { return value }
            if let index = args.firstIndex(of: "--page"), index + 1 < args.count { return args[index + 1] }
            return nil
        }()
        if let rawPage {
            switch rawPage.lowercased() {
            case "overview", "home": options.page = .overview
            case "scan", "smartscan", "smart-scan": options.page = .smartScan
            case "uninstaller", "apps": options.page = .uninstaller
            case "large", "largefiles", "large-files": options.page = .largeFiles
            case "space", "spacelens", "space-lens": options.page = .spaceLens
            case "load", "systemload", "system-load", "metrics": options.page = .systemLoad
            case "about", "aboutmac", "about-mac", "systeminfo": options.page = .about
            case "settings", "prefs": options.page = .settings
            default: options.page = AppPage(rawValue: rawPage.lowercased())
            }
        }

        if let value = environment["TIDYMAC_DEMO_STATE"] {
            options.demoState = value.lowercased()
        } else if let index = args.firstIndex(of: "--demo-state"), index + 1 < args.count {
            options.demoState = args[index + 1].lowercased()
        }
        return options
    }
}

/// A recently excluded scan item. Kept so the results screen can offer an undo
/// and explain that the location will be skipped by future scans.
struct ScanExclusionNotice: Identifiable, Equatable {
    let id = UUID()
    let itemName: String
    let addedPaths: [String]
    let item: ScanItem
    let category: ScanCategory
    let categoryIndex: Int
    let itemIndex: Int
}

@MainActor
final class AppState: ObservableObject {
    let settings = AppSettings.shared
    private let launchOptions = LaunchOptions.current

    @Published var page: AppPage = .overview
    @Published var disk = DiskInfo.empty
    @Published var phase: ScanPhase = .idle
    @Published var scanProgress = ScanProgress.idle
    @Published var scanResult: SmartScanResult?
    @Published var cleanProgress = CleanProgress.idle
    @Published var cleanReport: CleanReport?
    @Published var errorMessage: String?
    @Published var isDemo = false
    @Published var showPermissionHint = false
    @Published var exclusionNotice: ScanExclusionNotice?

    private var scanTask: Task<Void, Never>?
    private var demoProgressTask: Task<Void, Never>?
    private var exclusionNoticeTask: Task<Void, Never>?

    init() {
        isDemo = launchOptions.isDemo
        showPermissionHint = !FullDiskAccess.hasAccess()

        if isDemo {
            disk = DemoData.diskInfo
            scanResult = DemoData.scanResult()
            phase = .results
            switch launchOptions.demoState {
            case "scanning":
                phase = .scanning
                scanProgress = ScanProgress(fraction: 0.64,
                                            status: L("正在扫描开发者缓存…"),
                                            detail: "~/Library/Developer/Xcode/DerivedData")
                page = .smartScan
            case "idle":
                phase = .idle
                scanResult = nil
            case "empty":
                phase = .results
                var empty = DemoData.scanResult()
                empty.categories = empty.categories.map { category in
                    var copy = category
                    copy.items = []
                    return copy
                }
                scanResult = empty
            case "finished":
                phase = .finished
                cleanReport = CleanReport(removedCount: 23,
                                          freedBytes: 12_840_000_000,
                                          failures: [],
                                          completedAt: Date(),
                                          movedToTrash: true)
            default:
                phase = .results
            }
            if let page = launchOptions.page { self.page = page }
        } else {
            disk = DiskInfoProvider.current()
            if let page = launchOptions.page { self.page = page }
            if launchOptions.autoScan {
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self?.startSmartScan(trigger: "auto")
                }
            }
        }

        Analytics.shared.configure(language: settings.language, isDemo: isDemo)
        Analytics.shared.track(.appStart, [
            "language": .string(settings.language.analyticsCode),
            "appearance": .string(settings.appearance.rawValue),
            "initial_page": .string(page.rawValue)
        ])
    }

    // MARK: - Derived values

    var isScanning: Bool { phase == .scanning }
    var isCleaning: Bool { phase == .cleaning }

    var selectedItems: [ScanItem] {
        scanResult?.categories.flatMap { $0.items.filter(\.isSelected) } ?? []
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.byteCount }
    }

    var selectedCount: Int { selectedItems.count }

    var hasSelection: Bool { selectedCount > 0 }

    var groupedCategories: [(group: CleanupGroup, categories: [ScanCategory])] {
        let categories = scanResult?.categories ?? []
        return CleanupGroup.allCases
            .sorted { $0.order < $1.order }
            .compactMap { group in
                let matching = categories.filter { $0.group == group }
                guard !matching.isEmpty else { return nil }
                return (group, matching)
            }
    }

    var riskySelectedCount: Int {
        selectedItems.filter { $0.safety == .risky }.count
    }

    // MARK: - Navigation

    func navigate(to page: AppPage) {
        guard self.page != page else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            self.page = page
        }
        Analytics.shared.track(.pageView, ["page": .string(page.rawValue)])
        if page == .overview || page == .smartScan {
            refreshDisk()
        }
    }

    func refreshDisk() {
        if isDemo {
            disk = DemoData.diskInfo
        } else {
            disk = DiskInfoProvider.current()
        }
    }

    // MARK: - Scanning

    func startSmartScan(trigger: String = "user") {
        guard phase != .scanning && phase != .cleaning else { return }
        scanTask?.cancel()
        demoProgressTask?.cancel()
        dismissExclusionNotice()
        cleanReport = nil
        errorMessage = nil
        scanResult = nil
        phase = .scanning
        scanProgress = ScanProgress(fraction: 0.02, status: L("正在准备扫描…"), detail: L("检查可访问的缓存位置"))
        page = .smartScan
        Analytics.shared.track(.scanStart, [
            "trigger": .string(trigger),
            "excluded_count": .int(Int64(settings.excludedPaths.count))
        ])

        if isDemo {
            runDemoScan()
            return
        }

        let started = Date()
        let excluded = Set(settings.excludedPaths)
        scanTask = Task { [weak self] in
            guard let state = self else { return }
            let result = await SmartScanner.scan(excludedPaths: excluded) { progress in
                Task { @MainActor in
                    guard state.phase == .scanning else { return }
                    state.scanProgress = progress
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard state.phase == .scanning else { return }
                state.scanResult = SmartScanResult(
                    categories: result.categories,
                    freeBytes: result.freeBytes,
                    totalBytes: result.totalBytes,
                    scannedAt: Date(),
                    duration: Date().timeIntervalSince(started)
                )
                state.phase = .results
                state.scanProgress = ScanProgress(fraction: 1, status: L("扫描完成"))
                let finished = state.scanResult
                Analytics.shared.track(.scanComplete, [
                    "item_count": .int(Int64(finished?.totalItemCount ?? 0)),
                    "total_bytes": .int(finished?.totalBytesFound ?? 0),
                    "category_count": .int(Int64(finished?.categories.count ?? 0)),
                    "duration_ms": .int(Int64(Date().timeIntervalSince(started) * 1000))
                ])
                state.refreshDisk()
            }
        }
    }

    private func runDemoScan() {
        demoProgressTask = Task { [weak self] in
            let steps: [(Double, String, String)] = [
                (0.12, L("正在扫描用户缓存…"), "~/Library/Caches"),
                (0.28, L("正在检查日志与崩溃报告…"), "~/Library/Logs"),
                (0.44, L("正在分析 Xcode 构建缓存…"), "~/Library/Developer/Xcode/DerivedData"),
                (0.61, L("正在检查包管理器缓存…"), "~/.npm · Homebrew · pip"),
                (0.76, L("正在检查浏览器数据…"), "Safari · Chrome · Firefox"),
                (0.88, L("正在检查邮件附件与备份…"), "~/Library/Mail · MobileSync"),
                (1.0, L("扫描完成"), "")
            ]
            for step in steps {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 380_000_000)
                if Task.isCancelled { return }
                await MainActor.run { [weak self] in
                    guard let self, self.phase == .scanning else { return }
                    self.scanProgress = ScanProgress(fraction: step.0, status: step.1, detail: step.2)
                }
            }
            await MainActor.run { [weak self] in
                guard let self, self.phase == .scanning else { return }
                self.scanResult = DemoData.scanResult()
                self.phase = .results
                self.refreshDisk()
            }
        }
    }

    func cancelScan() {
        if phase == .scanning {
            let percent = Int((min(1, max(0, scanProgress.fraction)) * 100).rounded())
            Analytics.shared.track(.scanCancel, ["progress_percent": .int(Int64(percent))])
        }
        scanTask?.cancel()
        demoProgressTask?.cancel()
        scanTask = nil
        demoProgressTask = nil
        dismissExclusionNotice()
        phase = .idle
        scanProgress = .idle
        scanResult = nil
        refreshDisk()
    }

    func resetScan() {
        scanTask?.cancel()
        demoProgressTask?.cancel()
        dismissExclusionNotice()
        phase = .idle
        scanResult = nil
        cleanReport = nil
        scanProgress = .idle
        refreshDisk()
    }

    // MARK: - Selection

    func toggleItem(categoryID: String, itemID: String) {
        guard var result = scanResult,
              let categoryIndex = result.categories.firstIndex(where: { $0.id == categoryID }),
              let itemIndex = result.categories[categoryIndex].items.firstIndex(where: { $0.id == itemID })
        else { return }
        result.categories[categoryIndex].items[itemIndex].isSelected.toggle()
        scanResult = result
    }

    func setCategory(_ categoryID: String, selected: Bool) {
        guard var result = scanResult,
              let index = result.categories.firstIndex(where: { $0.id == categoryID })
        else { return }
        for itemIndex in result.categories[index].items.indices {
            result.categories[index].items[itemIndex].isSelected = selected
        }
        scanResult = result
    }

    func toggleCategory(_ categoryID: String) {
        guard let category = scanResult?.category(id: categoryID) else { return }
        setCategory(categoryID, selected: !category.isAllSelected)
    }

    func setAllCategories(selected: Bool) {
        guard var result = scanResult else { return }
        for categoryIndex in result.categories.indices {
            for itemIndex in result.categories[categoryIndex].items.indices {
                result.categories[categoryIndex].items[itemIndex].isSelected = selected
            }
        }
        scanResult = result
    }

    var allSelected: Bool {
        guard let categories = scanResult?.categories, !categories.isEmpty else { return false }
        let items = categories.flatMap(\.items)
        return !items.isEmpty && items.allSatisfy(\.isSelected)
    }

    // MARK: - Exclusions

    /// Adds every URL backing the item to the exclusion list and drops the item
    /// from the current results, so it can no longer be cleaned. `addedPaths`
    /// remembers exactly what was new, which keeps undo safe.
    func excludeItem(categoryID: String, itemID: String) {
        guard phase == .results,
              var result = scanResult,
              let categoryIndex = result.categories.firstIndex(where: { $0.id == categoryID }),
              let itemIndex = result.categories[categoryIndex].items.firstIndex(where: { $0.id == itemID })
        else { return }

        let category = result.categories[categoryIndex]
        let item = category.items[itemIndex]

        let targets = item.urls
            .filter { !settings.isExcluded($0) }
            .map(\.path)
        let addedPaths = settings.addExclusions(targets)
        guard !addedPaths.isEmpty else { return }

        result.categories[categoryIndex].items.remove(at: itemIndex)
        if result.categories[categoryIndex].items.isEmpty {
            result.categories.remove(at: categoryIndex)
        }
        scanResult = result

        Analytics.shared.track(.excludeItem, [
            "kind": .string(item.kind.rawValue),
            "path_count": .int(Int64(addedPaths.count)),
            "item_bytes": .int(item.byteCount)
        ])

        presentExclusionNotice(ScanExclusionNotice(itemName: L(item.name),
                                                   addedPaths: addedPaths,
                                                   item: item,
                                                   category: category,
                                                   categoryIndex: categoryIndex,
                                                   itemIndex: itemIndex))
    }

    func undoExclusion() {
        guard let notice = exclusionNotice else { return }
        settings.removeExclusions(notice.addedPaths)
        if var result = scanResult {
            if let index = result.categories.firstIndex(where: { $0.id == notice.category.id }) {
                if !result.categories[index].items.contains(where: { $0.id == notice.item.id }) {
                    let insertAt = min(notice.itemIndex, result.categories[index].items.count)
                    result.categories[index].items.insert(notice.item, at: insertAt)
                }
            } else {
                var restored = notice.category
                restored.items = [notice.item]
                let insertAt = min(notice.categoryIndex, result.categories.count)
                result.categories.insert(restored, at: insertAt)
            }
            scanResult = result
        }
        dismissExclusionNotice()
    }

    func dismissExclusionNotice() {
        exclusionNoticeTask?.cancel()
        exclusionNoticeTask = nil
        exclusionNotice = nil
    }

    private func presentExclusionNotice(_ notice: ScanExclusionNotice) {
        exclusionNoticeTask?.cancel()
        exclusionNotice = notice
        let id = notice.id
        exclusionNoticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, let self, self.exclusionNotice?.id == id else { return }
            self.dismissExclusionNotice()
        }
    }

    // MARK: - Cleaning

    func cleanSelected() {
        guard phase == .results, hasSelection else { return }
        let items = selectedItems
        let moveToTrash = settings.moveToTrash
        let excluded = Set(settings.excludedPaths)
        Analytics.shared.track(.cleanStart, [
            "item_count": .int(Int64(items.count)),
            "total_bytes": .int(items.reduce(0) { $0 + $1.byteCount }),
            "risky_count": .int(Int64(items.filter { $0.safety == .risky }.count)),
            "move_to_trash": .int(moveToTrash ? 1 : 0)
        ])
        phase = .cleaning
        cleanProgress = CleanProgress(fraction: 0.02, status: L("正在清理…"))
        errorMessage = nil

        if isDemo {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    let freed = items.reduce(0) { $0 + $1.byteCount }
                    let report = CleanReport(removedCount: items.count,
                                             freedBytes: freed,
                                             failures: [],
                                             completedAt: Date(),
                                             movedToTrash: moveToTrash)
                    self.finishClean(report)
                }
            }
            return
        }

        Task { [weak self] in
            guard let state = self else { return }
            let report = await Cleaner.clean(items: items,
                                             moveToTrash: moveToTrash,
                                             excludedPaths: excluded) { progress in
                Task { @MainActor in
                    guard state.phase == .cleaning else { return }
                    state.cleanProgress = progress
                }
            }
            await MainActor.run {
                state.finishClean(report)
            }
        }
    }

    private func finishClean(_ report: CleanReport) {
        Analytics.shared.track(.cleanComplete, [
            "removed_count": .int(Int64(report.removedCount)),
            "freed_bytes": .int(report.freedBytes),
            "failure_count": .int(Int64(report.failures.count)),
            "move_to_trash": .int(report.movedToTrash ? 1 : 0)
        ])
        cleanReport = report
        phase = .finished
        if !isDemo {
            settings.recordClean(report)
        }
        refreshDisk()
    }

    func dismissCleanSummary() {
        guard phase == .finished else { return }
        resetScan()
        page = .overview
    }
}
