import SwiftUI
import AppKit

// MARK: - View model

@MainActor
final class LargeFilesViewModel: ObservableObject {
    @Published var allFiles: [LargeFile] = []
    @Published var sizeFilter: LargeFileSizeFilter = .mb500
    @Published var ageFilter: LargeFileAgeFilter = .all
    @Published var kindFilter: LargeFileKind?
    @Published var sortDescending = true

    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus = "正在准备扫描…"
    @Published var hasScanned = false
    @Published var permissionDenied = false

    @Published var isTrashing = false
    @Published var report: CleanReport?
    @Published var showTrashConfirm = false
    @Published var hoveredID: String?

    private var scanTask: Task<Void, Never>?
    private var trashTask: Task<Void, Never>?

    // MARK: Derived values

    var filteredFiles: [LargeFile] {
        var result = allFiles.filter { $0.byteCount >= sizeFilter.bytes }
        if let days = ageFilter.days {
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
            result = result.filter { $0.modifiedAt <= cutoff }
        }
        if let kind = kindFilter {
            result = result.filter { $0.kind == kind }
        }
        result.sort { sortDescending ? $0.byteCount > $1.byteCount : $0.byteCount < $1.byteCount }
        return result
    }

    var selectedFiles: [LargeFile] { filteredFiles.filter(\.isSelected) }

    var selectedBytes: Int64 { selectedFiles.reduce(0) { $0 + $1.byteCount } }

    var foundBytes: Int64 { filteredFiles.reduce(0) { $0 + $1.byteCount } }

    /// Number of currently visible (filtered) rows that are selected.
    var visibleSelectedCount: Int { filteredFiles.filter(\.isSelected).count }

    var isAllVisibleSelected: Bool {
        !filteredFiles.isEmpty && visibleSelectedCount == filteredFiles.count
    }

    var isPartiallyVisibleSelected: Bool {
        visibleSelectedCount > 0 && !isAllVisibleSelected
    }

    var oldestFile: LargeFile? {
        filteredFiles.min { $0.modifiedAt < $1.modifiedAt }
    }

    var oldestAgeDays: Int {
        guard let oldest = oldestFile else { return 0 }
        return max(0, Int(Date().timeIntervalSince(oldest.modifiedAt) / 86_400))
    }

    // MARK: Scan

    func scan(isDemo: Bool, permissionHint: Bool) {
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        scanStatus = "正在准备扫描…"
        report = nil
        permissionDenied = false

        if isDemo {
            scanTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 260_000_000)
                guard let self, !Task.isCancelled else { return }
                // Real scans skip ~/Library, so keep demo content consistent with that.
                let libraryPrefix = HomePaths.home.appendingPathComponent("Library").path + "/"
                var files = DemoData.largeFiles.filter { !$0.url.path.hasPrefix(libraryPrefix) }
                files.sort { $0.byteCount > $1.byteCount }
                self.allFiles = files
                self.isScanning = false
                self.hasScanned = true
                self.scanProgress = 1
                self.scanStatus = "扫描完成"
            }
            return
        }

        let roots = [
            HomePaths.url("Downloads"),
            HomePaths.url("Documents"),
            HomePaths.url("Desktop"),
            HomePaths.url("Movies"),
            HomePaths.url("Pictures"),
            HomePaths.url("Music")
        ]

        scanTask = Task { [weak self] in
            guard let self else { return }
            let files = await LargeFilesEngine.scan(roots: roots,
                                                    minSize: 100_000_000,
                                                    minAgeDays: nil) { progress, status in
                Task { @MainActor [weak self] in
                    guard let self, self.isScanning else { return }
                    self.scanProgress = progress
                    self.scanStatus = status
                }
            }
            guard !Task.isCancelled else { return }
            self.allFiles = files
            self.isScanning = false
            self.hasScanned = true
            self.scanProgress = 1
            self.scanStatus = "扫描完成"
            self.permissionDenied = files.isEmpty && permissionHint
        }
    }

    func rescan(isDemo: Bool, permissionHint: Bool) {
        scan(isDemo: isDemo, permissionHint: permissionHint)
    }

    // MARK: Selection

    func toggle(_ file: LargeFile) {
        guard let index = allFiles.firstIndex(where: { $0.id == file.id }) else { return }
        allFiles[index].isSelected.toggle()
    }

    /// Selects or deselects every file that is currently visible under the
    /// active filters. Hidden rows keep their existing state.
    func setAllVisibleSelected(_ selected: Bool) {
        let visibleIDs = Set(filteredFiles.map(\.id))
        for index in allFiles.indices where visibleIDs.contains(allFiles[index].id) {
            allFiles[index].isSelected = selected
        }
    }

    func toggleSelectAllVisible() {
        setAllVisibleSelected(!isAllVisibleSelected)
    }

    func clearSelection() {
        for index in allFiles.indices {
            allFiles[index].isSelected = false
        }
    }

    var confirmMessage: String {
        L("将把 \(selectedFiles.count) 个文件（\(Format.bytes(selectedBytes))）移到废纸篓。\n移到废纸篓的文件可随时恢复，不会立即释放磁盘空间，清空废纸篓后才会真正释放。")
    }

    // MARK: Trash

    func confirmTrash(isDemo: Bool) {
        let chosen = selectedFiles
        guard !chosen.isEmpty, !isTrashing else { return }
        isTrashing = true
        report = nil

        if isDemo {
            trashTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 760_000_000)
                guard let self, !Task.isCancelled else { return }
                let freed = chosen.reduce(0) { $0 + $1.byteCount }
                let ids = Set(chosen.map(\.id))
                self.allFiles.removeAll { ids.contains($0.id) }
                self.isTrashing = false
                self.report = CleanReport(removedCount: chosen.count,
                                          freedBytes: freed,
                                          failures: [],
                                          completedAt: Date(),
                                          movedToTrash: true)
            }
            return
        }

        trashTask = Task { [weak self] in
            guard let self else { return }
            let result = await LargeFilesEngine.trash(files: chosen) { _, _ in }
            let failurePaths = Set(result.failures.map(\.path))
            let removedIDs = Set(chosen.filter { !failurePaths.contains($0.url.path) }.map(\.id))
            self.allFiles.removeAll { removedIDs.contains($0.id) }
            self.isTrashing = false
            self.report = result
        }
    }

    func dismissReport() {
        report = nil
    }
}

// MARK: - Page

struct LargeFilesPage: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var model = LargeFilesViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "大文件", subtitle: "找出最占空间的文件") {
                rescanButton
            }

            filterBar

            summaryRow

            if let report = model.report {
                LargeFilesResultBanner(report: report, dismiss: { model.dismissReport() })
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            listPanel
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 30)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.24), value: model.report?.completedAt)
        .onAppear {
            guard !model.hasScanned, !model.isScanning else { return }
            model.scan(isDemo: app.isDemo, permissionHint: app.showPermissionHint)
        }
        .alert("移入废纸篓？", isPresented: $model.showTrashConfirm) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                model.confirmTrash(isDemo: app.isDemo)
            }
        } message: {
            Text(L(model.confirmMessage))
        }
    }

    // MARK: Header

    private var rescanButton: some View {
        Button {
            guard !model.isScanning, !model.isTrashing else { return }
            model.rescan(isDemo: app.isDemo, permissionHint: app.showPermissionHint)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text(L("重新扫描"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(Capsule(style: .continuous).fill(Theme.cardElevated))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(model.isScanning || model.isTrashing)
        .opacity(model.isScanning || model.isTrashing ? 0.5 : 1)
    }

    // MARK: Filters

    private var filterBar: some View {
        HStack(spacing: 6) {
            filterLabel("大小")
            ForEach(LargeFileSizeFilter.allCases) { option in
                FilterPill(title: option.title,
                           isSelected: model.sizeFilter == option,
                           tone: .mint) {
                    model.sizeFilter = option
                }
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1, height: 18)
                .padding(.horizontal, 4)

            filterLabel("时间")
            ForEach(LargeFileAgeFilter.allCases) { option in
                FilterPill(title: option.title,
                           isSelected: model.ageFilter == option,
                           tone: .blue) {
                    model.ageFilter = option
                }
            }

            Spacer(minLength: 6)

            kindMenu
        }
        .frame(height: 36)
    }

    private func filterLabel(_ text: String) -> some View {
        Text(L(text))
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Theme.textTertiary)
    }

    private var kindMenu: some View {
        Menu {
            Button {
                model.kindFilter = nil
            } label: {
                Label("全部类型", systemImage: "square.grid.2x2")
            }
            Divider()
            ForEach(LargeFileKind.allCases) { kind in
                Button {
                    model.kindFilter = kind
                } label: {
                    Label(kind.title, systemImage: kind.symbol)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(L(model.kindFilter?.title ?? "全部类型"))
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(model.kindFilter == nil ? Theme.textSecondary : Theme.mint)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(Capsule(style: .continuous).fill(Theme.cardElevated))
            .overlay(Capsule(style: .continuous)
                .strokeBorder(model.kindFilter == nil ? Theme.stroke : Theme.mint.opacity(0.35),
                              lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: Summary

    private var summaryRow: some View {
        HStack(spacing: 14) {
            let found = Format.bytesParts(model.foundBytes)
            StatTile(title: "找到文件",
                     value: found.number,
                     unit: found.unit,
                     symbol: "doc.zipper",
                     tone: .mint,
                     caption: L("共 \(model.filteredFiles.count) 个匹配文件"))
                .frame(maxWidth: .infinity)

            let selected = Format.bytesParts(model.selectedBytes)
            StatTile(title: "已选文件",
                     value: selected.number,
                     unit: selected.unit,
                     symbol: "checkmark.circle.fill",
                     tone: .blue,
                     caption: L("\(model.selectedFiles.count) 项待清理"))
                .frame(maxWidth: .infinity)

            StatTile(title: "最旧文件",
                     value: "\(model.oldestAgeDays)",
                     unit: "天",
                     symbol: "clock.fill",
                     tone: .orange,
                     caption: model.oldestFile?.name ?? "暂无文件")
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: List

    private var listPanel: some View {
        VStack(spacing: 0) {
            LargeFilesTableHeader(sortDescending: model.sortDescending,
                                  isAllSelected: model.isAllVisibleSelected,
                                  isPartiallySelected: model.isPartiallyVisibleSelected,
                                  isEnabled: !model.filteredFiles.isEmpty && !model.isScanning && !model.isTrashing,
                                  toggleSort: { model.sortDescending.toggle() },
                                  toggleAll: { model.toggleSelectAllVisible() })
            DividerLine()

            Group {
                if model.isScanning && !model.hasScanned {
                    scanningState
                } else if model.permissionDenied {
                    permissionState
                } else if model.filteredFiles.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .frame(maxHeight: .infinity)

            DividerLine()
            footer
        }
        .qyPanel(padding: 0)
    }

    private var fileList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(model.filteredFiles) { file in
                    LargeFileRowView(file: file,
                                     isSelected: file.isSelected,
                                     isHovered: model.hoveredID == file.id,
                                     onToggle: { model.toggle(file) },
                                     onReveal: {
                                         NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                     })
                        .onHover { hovering in
                            if hovering {
                                model.hoveredID = file.id
                            } else if model.hoveredID == file.id {
                                model.hoveredID = nil
                            }
                        }
                }
            }
            .padding(.vertical, 3)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [Color.clear, Theme.card],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
                .allowsHitTesting(false)
        }
    }

    private var scanningState: some View {
        VStack(spacing: 0) {
            LargeFilesScanningState(progress: model.scanProgress, status: model.scanStatus)
                .padding(.top, 20)
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    LargeFilesSkeletonRow()
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionState: some View {
        EmptyStateView(symbol: "lock.shield.fill",
                       title: "需要磁盘访问权限",
                       message: "未能读取文件列表。请在「系统设置 › 隐私与安全性 › 完全磁盘访问权限」中允许 TidyMac 访问，然后重新扫描。",
                       actionTitle: "重新扫描") {
            model.rescan(isDemo: app.isDemo, permissionHint: app.showPermissionHint)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(symbol: "doc.zipper",
                       title: model.hasScanned ? "没有符合条件的大文件" : "尚未扫描",
                       message: model.hasScanned
                        ? "试试降低大小阈值、调整时间范围，或点击重新扫描。"
                        : "点击开始扫描，在下载、文档、桌面等目录中找出最占空间的文件。",
                       actionTitle: model.hasScanned ? "重新扫描" : "开始扫描") {
            model.rescan(isDemo: app.isDemo, permissionHint: app.showPermissionHint)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if model.selectedFiles.isEmpty {
                    Text(L("未选择文件"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Text(L(model.isScanning ? "扫描完成后可勾选清理" : "选择文件后可移入废纸篓"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text(L("已选 \(model.selectedFiles.count) 项"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Text(L("共 \(Format.bytes(model.selectedBytes))"))
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            if !model.filteredFiles.isEmpty && !model.isScanning {
                Button {
                    model.toggleSelectAllVisible()
                } label: {
                    Text(L(model.isAllVisibleSelected ? "取消全选" : "全选"))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule(style: .continuous).fill(Theme.cardElevated))
                        .overlay(Capsule(style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help(model.isAllVisibleSelected ? "取消全选当前列表" : L("全选当前列表中的 \(model.filteredFiles.count) 个文件"))
            }

            if model.isScanning && model.hasScanned {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text(L(model.scanStatus))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if model.isTrashing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text(L("正在移入废纸篓…"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Button {
                    model.showTrashConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L("移入废纸篓"))
                    }
                }
                .buttonStyle(DangerButtonStyle(compact: true))
                .disabled(model.selectedFiles.isEmpty)
                .opacity(model.selectedFiles.isEmpty ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
