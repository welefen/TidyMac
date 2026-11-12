import SwiftUI

struct DashboardPage: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var permissionDismissed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                PageHeader(title: "总览", subtitle: "查看可回收空间与最近清理") {
                    QYAvailableSpacePill(disk: app.disk)
                }

                if showsPermissionHint {
                    DashboardPermissionBanner {
                        withAnimation(.easeOut(duration: 0.15)) { permissionDismissed = true }
                    }
                    .transition(.opacity)
                }

                DashboardHeroCard()

                DashboardBreakdown(metrics: metrics, hasResult: app.scanResult != nil)

                quickToolsSection
                historySection
                safetyFooter
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeOut(duration: 0.15), value: showsPermissionHint)
    }

    // MARK: - Permission

    private var showsPermissionHint: Bool {
        app.showPermissionHint && !app.isDemo && !permissionDismissed
    }

    // MARK: - Metrics

    private var metrics: [DashboardMetric] {
        guard let result = app.scanResult else { return [] }

        func total(_ groups: [CleanupGroup]) -> (bytes: Int64, count: Int) {
            let categories = result.categories.filter { groups.contains($0.group) }
            return (categories.reduce(0) { $0 + $1.totalBytes },
                    categories.reduce(0) { $0 + $1.itemCount })
        }

        func item(id: String, title: String, groups: [CleanupGroup]) -> DashboardMetric {
            let value = total(groups)
            return DashboardMetric(id: id, title: title, bytes: value.bytes, count: value.count)
        }

        return [
            item(id: "system", title: "系统垃圾", groups: [.systemJunk, .trash]),
            item(id: "developer", title: "开发者垃圾", groups: [.developerJunk]),
            item(id: "browser", title: "浏览器数据", groups: [.browserJunk]),
            item(id: "mail", title: "邮件与备份", groups: [.mailAttachments, .iosBackups])
        ]
    }

    // MARK: - Quick tools

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "快捷工具", subtitle: "其他管理空间的方式")
            VStack(spacing: 0) {
                DashboardToolRow(page: .uninstaller,
                                 title: "卸载器",
                                 subtitle: "卸载应用并清理残留文件",
                                 symbol: "trash.slash")
                DividerLine()
                DashboardToolRow(page: .largeFiles,
                                 title: "大文件",
                                 subtitle: "找出最占空间的单个文件",
                                 symbol: "doc.zipper")
                DividerLine()
                DashboardToolRow(page: .spaceLens,
                                 title: "空间透镜",
                                 subtitle: "查看每个文件夹的占用",
                                 symbol: "circle.hexagongrid")
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
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
            Image(systemName: "checkmark.shield")
                .font(.system(size: 10, weight: .regular))
            Text(L("所有清理均经过安全校验，默认移入废纸篓"))
                .font(.system(size: 11))
        }
        .foregroundStyle(Theme.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - Models

struct DashboardMetric: Identifiable {
    let id: String
    let title: String
    let bytes: Int64
    let count: Int
}
