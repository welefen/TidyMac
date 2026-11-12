import SwiftUI
import AppKit

// MARK: - View model

@MainActor
final class UninstallerViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var loadProgress: Double = 0
    @Published var loadStatus = "正在准备…"

    @Published var searchText = ""
    @Published var sort: AppSortOption = .size

    @Published var selectedAppID: String?
    @Published var leftovers: [LeftoverItem] = []
    @Published var isLoadingLeftovers = false

    @Published var isUninstalling = false
    @Published var uninstallProgress: Double = 0
    @Published var uninstallStatus = ""

    @Published var showConfirm = false
    @Published var report: CleanReport?
    @Published var finishedAppName = ""

    private var demoMode = false
    private var uninstallMovedToTrash = true
    private var loadTask: Task<Void, Never>?
    private var leftoverTask: Task<Void, Never>?
    private var uninstallTask: Task<Void, Never>?

    // MARK: Derived

    var filteredApps: [InstalledApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = apps
        if !query.isEmpty {
            result = result.filter { app in
                app.name.localizedCaseInsensitiveContains(query)
                    || (app.bundleID ?? "").localizedCaseInsensitiveContains(query)
            }
        }
        switch sort {
        case .size:
            result.sort { $0.byteCount > $1.byteCount }
        case .name:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .lastUsed:
            result.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }
        return result
    }

    var selectedApp: InstalledApp? {
        guard let selectedAppID else { return nil }
        return apps.first { $0.id == selectedAppID }
    }

    var selectedLeftovers: [LeftoverItem] { leftovers.filter(\.isSelected) }

    var leftoverTotalBytes: Int64 {
        leftovers.reduce(0) { $0 + $1.byteCount }
    }

    var selectedLeftoverBytes: Int64 {
        selectedLeftovers.reduce(0) { $0 + $1.byteCount }
    }

    var selectedTotalBytes: Int64 {
        (selectedApp?.byteCount ?? 0) + selectedLeftoverBytes
    }

    var allLeftoversSelected: Bool {
        !leftovers.isEmpty && leftovers.allSatisfy(\.isSelected)
    }

    // MARK: Loading

    func load(isDemo: Bool, includeSystem: Bool) {
        demoMode = isDemo
        loadTask?.cancel()
        isLoading = true
        loadProgress = 0
        loadStatus = isDemo ? "正在读取演示数据…" : "正在扫描应用程序…"
        report = nil
        selectedAppID = nil
        leftovers = []
        isLoadingLeftovers = false

        if isDemo {
            loadTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard let self, !Task.isCancelled else { return }
                self.apps = DemoData.applications
                self.isLoading = false
                self.loadProgress = 1
                self.loadStatus = "已加载应用"
                if let first = self.filteredApps.first { self.select(first) }
            }
            return
        }

        loadTask = Task { [weak self] in
            guard let self else { return }
            let loaded = await UninstallerEngine.loadApplications(includeSystem: includeSystem) { progress, status in
                Task { @MainActor [weak self] in
                    guard let self, self.isLoading else { return }
                    self.loadProgress = progress
                    self.loadStatus = status
                }
            }
            guard !Task.isCancelled else { return }
            self.apps = loaded
            self.isLoading = false
            self.loadProgress = 1
            self.loadStatus = L("已加载 \(loaded.count) 个应用")
            if let first = self.filteredApps.first { self.select(first) }
        }
    }

    func refresh(includeSystem: Bool) {
        load(isDemo: demoMode, includeSystem: includeSystem)
    }

    // MARK: Selection

    func select(_ app: InstalledApp) {
        guard selectedAppID != app.id else { return }
        selectedAppID = app.id
        leftovers = []
        isLoadingLeftovers = true
        leftoverTask?.cancel()

        leftoverTask = Task { [weak self] in
            guard let self else { return }
            if self.demoMode {
                try? await Task.sleep(nanoseconds: 240_000_000)
                guard !Task.isCancelled, self.selectedAppID == app.id else { return }
                self.leftovers = DemoData.leftovers(for: app)
                self.isLoadingLeftovers = false
                return
            }
            let items = await UninstallerEngine.findLeftovers(for: app) { _, _ in }
            guard !Task.isCancelled, self.selectedAppID == app.id else { return }
            self.leftovers = items
            self.isLoadingLeftovers = false
        }
    }

    func toggleLeftover(_ id: String) {
        guard let index = leftovers.firstIndex(where: { $0.id == id }) else { return }
        leftovers[index].isSelected.toggle()
    }

    func setAllLeftovers(_ selected: Bool) {
        for index in leftovers.indices {
            leftovers[index].isSelected = selected
        }
    }

    // MARK: Uninstall

    func confirmMessage(moveToTrash: Bool) -> String {
        guard let app = selectedApp else { return "" }
        let leftoverPart: String
        if selectedLeftovers.isEmpty {
            leftoverPart = L("仅移除应用本体")
        } else {
            leftoverPart = L("以及 \(selectedLeftovers.count) 项关联文件（\(Format.bytes(selectedLeftoverBytes))）")
        }
        let mode = L(moveToTrash
            ? "这些项目会被移到废纸篓，可在废纸篓中恢复。"
            : "这些项目将被直接删除，无法恢复。")
        var text = L("将移除 %@（%@）%@，合计 %@。", app.name, Format.bytes(app.byteCount), leftoverPart, Format.bytes(selectedTotalBytes))
        text += "\n" + mode
        if isRunning(app) {
            text += L("\n应用当前正在运行，建议先退出。")
        }
        if ToolsSupport.requiresAdministrator(for: app.url) {
            text += L("\n卸载此 App Store 应用需要输入管理员密码。")
        }
        return text
    }

    func confirmUninstall(isDemo: Bool, moveToTrash: Bool) {
        guard let app = selectedApp, !isUninstalling, !app.isSystem else { return }
        finishedAppName = app.name
        isUninstalling = true
        uninstallProgress = 0.03
        uninstallStatus = "正在准备移除…"
        let chosen = selectedLeftovers
        let freed = app.byteCount + chosen.reduce(0) { $0 + $1.byteCount }
        uninstallMovedToTrash = moveToTrash
        Analytics.shared.track(.uninstallStart, [
            "leftover_count": .int(Int64(chosen.count)),
            "total_bytes": .int(freed),
            "move_to_trash": .int(moveToTrash ? 1 : 0)
        ])

        if isDemo {
            uninstallTask = Task { [weak self] in
                guard let self else { return }
                let steps: [(Double, String)] = [
                    (0.18, "正在退出应用…"),
                    (0.42, "正在移除应用本体…"),
                    (0.68, "正在清理关联文件…"),
                    (0.90, "正在完成…")
                ]
                for step in steps {
                    try? await Task.sleep(nanoseconds: 230_000_000)
                    guard !Task.isCancelled else { return }
                    self.uninstallProgress = step.0
                    self.uninstallStatus = step.1
                }
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                let report = CleanReport(removedCount: 1 + chosen.count,
                                         freedBytes: freed,
                                         failures: [],
                                         completedAt: Date(),
                                         movedToTrash: moveToTrash)
                self.finishUninstall(report, appID: app.id)
            }
            return
        }

        let needsAdmin = ToolsSupport.requiresAdministrator(for: app.url)

        uninstallTask = Task { [weak self] in
            guard let self else { return }
            if needsAdmin {
                // Let the SwiftUI confirmation alert finish dismissing first;
                // otherwise the app can re-activate itself over the system
                // authorization dialog and hide it behind the main window.
                try? await Task.sleep(nanoseconds: 450_000_000)
                NSApp.hide(nil)
            }
            let report = await UninstallerEngine.uninstall(app: app,
                                                          leftovers: chosen,
                                                          moveToTrash: moveToTrash) { progress, status in
                Task { @MainActor [weak self] in
                    guard let self, self.isUninstalling else { return }
                    self.uninstallProgress = progress
                    self.uninstallStatus = status
                }
            }
            if needsAdmin {
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            self.finishUninstall(report, appID: app.id)
        }
    }

    private func finishUninstall(_ report: CleanReport, appID: String) {
        Analytics.shared.track(.uninstallComplete, [
            "removed_count": .int(Int64(report.removedCount)),
            "freed_bytes": .int(report.freedBytes),
            "failure_count": .int(Int64(report.failures.count)),
            "move_to_trash": .int(uninstallMovedToTrash ? 1 : 0)
        ])
        isUninstalling = false
        uninstallProgress = 1
        self.report = report
        if report.failures.isEmpty {
            apps.removeAll { $0.id == appID }
            selectedAppID = nil
            leftovers = []
            isLoadingLeftovers = false
        }
    }

    func dismissReport() {
        report = nil
    }

    // MARK: Helpers

    func isRunning(_ app: InstalledApp) -> Bool {
        guard let bundleID = app.bundleID else { return false }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }
}

// MARK: - Page

struct UninstallerPage: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model = UninstallerViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(title: "卸载器", subtitle: "移除应用并清理关联文件") {
                HStack(spacing: 8) {
                    SearchField(text: $model.searchText, placeholder: "搜索应用或 Bundle ID")
                        .frame(width: 216)
                    sortMenu
                    refreshButton
                }
            }

            if let report = model.report {
                UninstallResultBanner(report: report,
                                      appName: model.finishedAppName,
                                      dismiss: { model.dismissReport() })
                    .transition(.opacity)
            }

            HStack(alignment: .top, spacing: 20) {
                appListPanel
                detailPanel
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.18), value: model.report?.completedAt)
        .onAppear {
            guard model.apps.isEmpty else { return }
            model.load(isDemo: app.isDemo, includeSystem: settings.showSystemApps)
        }
        .alert(Text(L("卸载 %@？", model.selectedApp?.name ?? L("应用"))),
               isPresented: $model.showConfirm) {
            Button("取消", role: .cancel) {}
            Button(L(settings.moveToTrash ? "移到废纸篓" : "直接删除"), role: .destructive) {
                model.confirmUninstall(isDemo: app.isDemo, moveToTrash: settings.moveToTrash)
            }
        } message: {
            Text(model.confirmMessage(moveToTrash: settings.moveToTrash))
        }
    }

    // MARK: Header controls

    private var sortMenu: some View {
        Menu {
            ForEach(AppSortOption.allCases) { option in
                Button {
                    model.sort = option
                } label: {
                    Label(option.title, systemImage: option.symbol)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10, weight: .medium))
                Text(L(model.sort.title))
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.field)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var refreshButton: some View {
        Button {
            guard !model.isLoading, !model.isUninstalling else { return }
            model.refresh(includeSystem: settings.showSystemApps)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                Text(L("刷新"))
            }
        }
        .buttonStyle(SecondaryButtonStyle(tone: .mint, compact: true))
        .disabled(model.isLoading || model.isUninstalling)
        .opacity(model.isLoading || model.isUninstalling ? 0.5 : 1)
    }

    // MARK: Application list

    private var appListPanel: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.isLoading ? "正在加载应用" : "已安装应用")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                if !model.isLoading {
                    Text(Format.itemCount(model.filteredApps.count))
                        .font(Theme.monoFont(10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if model.isLoading {
                    Text(Format.percent(model.loadProgress))
                        .font(Theme.monoFont(10.5, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text(Format.bytes(model.apps.reduce(0) { $0 + $1.byteCount }))
                        .font(Theme.monoFont(10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            DividerLine()

            Group {
                if model.isLoading {
                    loadingList
                } else if model.filteredApps.isEmpty {
                    EmptyStateView(symbol: "magnifyingglass",
                                   title: "没有匹配的应用",
                                   message: "试试其他关键词，或点击刷新重新读取应用程序目录。")
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            ForEach(model.filteredApps) { installed in
                                AppListRow(app: installed,
                                           isSelected: model.selectedAppID == installed.id,
                                           isRunning: model.isRunning(installed)) {
                                    model.select(installed)
                                }
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .qyPanel(padding: 0)
    }

    private var loadingList: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text(L(model.loadStatus))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
            ForEach(0..<6, id: \.self) { _ in
                AppListSkeletonRow()
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailPanel: some View {
        if let installed = model.selectedApp {
            detailContent(installed)
        } else {
            VStack {
                EmptyStateView(symbol: "trash.slash",
                               title: "选择一个应用",
                               message: "从左侧列表选择要卸载的应用，查看并移除其关联残留文件。")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .qyPanel(padding: 18)
        }
    }

    private func detailContent(_ installed: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader(installed)
            DividerLine()
                .padding(.vertical, 14)
            metricsRow(installed)
            if installed.isSystem {
                systemAppNotice
                    .padding(.top, 14)
            }
            if model.isRunning(installed) {
                RunningAppWarning()
                    .padding(.top, 14)
            }
            if !installed.isSystem {
                leftoversHeader
                    .padding(.top, 18)
                    .padding(.bottom, 4)
                leftoversBody
                if !model.leftovers.isEmpty && !model.isLoadingLeftovers {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text(L("勾选的残留会随应用一起移除；取消勾选可保留偏好设置等数据。"))
                            .font(.system(size: 10.5))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 8)
                }
            }
            actionBar(installed)
                .padding(.top, 14)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .qyPanel(padding: 0)
    }

    private func detailHeader(_ installed: InstalledApp) -> some View {
        HStack(alignment: .top, spacing: 14) {
            AppGlyphView(app: installed, size: 56)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(L(installed.name))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if installed.isSystem {
                        Text(L("系统应用"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                HStack(spacing: 6) {
                    Text(L("版本 \(installed.version)"))
                    Text("·")
                    Text(L(installed.isSystem ? "系统安装" : "用户安装"))
                }
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textSecondary)
                Text(L(installed.bundleID ?? "未知 Bundle ID"))
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
        }
    }

    private func metricsRow(_ installed: InstalledApp) -> some View {
        HStack(spacing: 0) {
            MiniMetric(title: "占用空间", value: Format.bytes(installed.byteCount), mono: true)
            MetricDivider()
            MiniMetric(title: "上次使用", value: relativeUsageText(installed.lastUsed))
            MetricDivider()
            MiniMetric(title: "关联残留",
                       value: model.isLoadingLeftovers ? "检查中…" : Format.bytes(model.leftoverTotalBytes),
                       mono: true)
            Spacer(minLength: 0)
        }
    }

    private var leftoversHeader: some View {
        HStack(spacing: 8) {
            Text(L("关联文件"))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            if !model.leftovers.isEmpty {
                Text(Format.itemCount(model.leftovers.count))
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
                Text("· \(Format.bytes(model.leftoverTotalBytes))")
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if !model.leftovers.isEmpty && !model.isLoadingLeftovers {
                Button(L(model.allLeftoversSelected ? "取消全选" : "全选")) {
                    model.setAllLeftovers(!model.allLeftoversSelected)
                }
                .buttonStyle(GhostButtonStyle(tone: .mint))
            }
        }
    }

    private var leftoversBody: some View {
        Group {
            if model.isLoadingLeftovers {
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        LeftoverSkeletonRow()
                    }
                    Spacer(minLength: 0)
                }
            } else if model.leftovers.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                    Text(L("未发现关联残留，将仅移除应用本体。"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(model.leftovers) { item in
                            LeftoverRowView(item: item) {
                                model.toggleLeftover(item.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var systemAppNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.shield")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("系统应用受 SIP 保护"))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(L("这类应用由 macOS 系统完整性保护管理，TidyMac 无法移除。此处仅用于查看系统组件占用。"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.field)
        )
    }

    private func actionBar(_ installed: InstalledApp) -> some View {
        VStack(spacing: 12) {
            DividerLine()
            if model.isUninstalling {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(L(model.uninstallStatus))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(Format.percent(model.uninstallProgress))
                            .font(Theme.monoFont(11.5, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    CapacityRuler(fraction: model.uninstallProgress, height: 5)
                }
            } else if installed.isSystem {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("系统应用不可卸载"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text(L("受 macOS 系统完整性保护（SIP）限制，TidyMac 只能查看占用信息。"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Image(systemName: "lock")
                            .font(.system(size: 10, weight: .medium))
                        Text(L("系统应用不可卸载"))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                }
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.selectedLeftovers.isEmpty
                             ? L("将移除应用本体")
                             : L("将移除应用及 \(model.selectedLeftovers.count) 项残留"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                        Text(L("共 \(Format.bytes(model.selectedTotalBytes))"))
                            .font(Theme.monoFont(15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        model.showConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.slash")
                                .font(.system(size: 11, weight: .medium))
                            Text(L("卸载应用"))
                        }
                    }
                    .buttonStyle(DangerButtonStyle())
                }
            }
        }
    }
}

private struct LeftoverSkeletonRow: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 17, height: 17)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.cardElevated)
                    .frame(width: 130, height: 9)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.cardElevated.opacity(0.6))
                    .frame(width: 210, height: 7)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 44, height: 9)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
