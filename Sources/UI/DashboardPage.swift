import SwiftUI

struct DashboardPage: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var permissionDismissed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "总览", subtitle: "让 Mac 轻净如羽") {
                    QYAvailableSpacePill(disk: app.disk)
                }

                if showsPermissionHint {
                    DashboardPermissionBanner {
                        withAnimation(.easeInOut(duration: 0.2)) { permissionDismissed = true }
                    }
                    .transition(.opacity)
                }

                DashboardHeroCard()

                metricsSection
                quickToolsSection
                historySection
                safetyFooter
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeInOut(duration: 0.2), value: showsPermissionHint)
    }

    // MARK: - Permission

    private var showsPermissionHint: Bool {
        app.showPermissionHint && !app.isDemo && !permissionDismissed
    }

    // MARK: - Metrics

    private var metricColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
    }

    private var metricItems: [DashboardMetricItem] {
        let result = app.scanResult
        let scanning = app.phase == .scanning

        func total(_ groups: [CleanupGroup]) -> (bytes: Int64, count: Int) {
            guard let result else { return (0, 0) }
            let categories = result.categories.filter { groups.contains($0.group) }
            return (categories.reduce(0) { $0 + $1.totalBytes },
                    categories.reduce(0) { $0 + $1.itemCount })
        }

        func makeItem(id: String, title: String, symbol: String, tone: AccentTone,
                      groups: [CleanupGroup]) -> DashboardMetricItem {
            let value = total(groups)
            if result == nil {
                return DashboardMetricItem(id: id, title: title, symbol: symbol, tone: tone,
                                           value: "—", unit: nil,
                                           caption: scanning ? "扫描中…" : "扫描后显示")
            }
            if value.count == 0 {
                return DashboardMetricItem(id: id, title: title, symbol: symbol, tone: tone,
                                           value: "0", unit: "B", caption: "无需清理")
            }
            let parts = Format.bytesParts(value.bytes)
            return DashboardMetricItem(id: id, title: title, symbol: symbol, tone: tone,
                                       value: parts.number, unit: parts.unit,
                                       caption: L("\(value.count) 项可清理"))
        }

        return [
            makeItem(id: "system", title: "系统垃圾", symbol: "shippingbox.fill",
                     tone: .mint, groups: [.systemJunk, .trash]),
            makeItem(id: "developer", title: "开发者垃圾", symbol: "hammer.fill",
                     tone: .purple, groups: [.developerJunk]),
            makeItem(id: "browser", title: "浏览器数据", symbol: "safari.fill",
                     tone: .blue, groups: [.browserJunk]),
            makeItem(id: "mail", title: "邮件与备份", symbol: "envelope.fill",
                     tone: .pink, groups: [.mailAttachments, .iosBackups])
        ]
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "空间分类",
                          subtitle: app.scanResult == nil ? "扫描后显示各类垃圾占用" : "来自最近一次智能扫描")
            LazyVGrid(columns: metricColumns, spacing: 14) {
                ForEach(metricItems) { item in
                    StatTile(title: item.title,
                             value: item.value,
                             unit: item.unit,
                             symbol: item.symbol,
                             tone: item.tone,
                             caption: item.caption)
                }
            }
        }
    }

    // MARK: - Quick tools

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "快捷工具", subtitle: "更多空间管理方式")
            HStack(spacing: 14) {
                DashboardQuickToolCard(page: .uninstaller,
                                       title: "卸载器",
                                       subtitle: "卸载应用并清理残留文件",
                                       symbol: "trash.slash.fill",
                                       tone: .purple)
                DashboardQuickToolCard(page: .largeFiles,
                                       title: "大文件",
                                       subtitle: "找出最占空间的单个文件",
                                       symbol: "doc.zipper",
                                       tone: .orange)
                DashboardQuickToolCard(page: .spaceLens,
                                       title: "空间透镜",
                                       subtitle: "用可视化地图看清占用",
                                       symbol: "circle.hexagongrid.fill",
                                       tone: .blue)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近清理",
                          subtitle: settings.history.isEmpty ? nil : L("最近 \(min(3, settings.history.count)) 条记录"))
            DashboardHistoryCard()
        }
    }

    // MARK: - Footer

    private var safetyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 9.5))
            Text(L("所有清理均经过安全校验，默认移入废纸篓"))
                .font(.system(size: 10.5))
        }
        .foregroundStyle(Theme.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - Models

private struct DashboardMetricItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tone: AccentTone
    let value: String
    let unit: String?
    let caption: String
}
