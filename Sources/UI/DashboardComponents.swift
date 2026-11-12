import SwiftUI

// MARK: - Header accessory (shared by 总览 / 智能扫描)

/// Quiet disk summary for the trailing edge of `PageHeader`.
struct QYAvailableSpacePill: View {
    let disk: DiskInfo

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(L("可用空间"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Text(Format.bytes(max(0, disk.freeBytes)))
                .font(Theme.monoFont(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Text(L("共 \(Format.bytes(disk.totalBytes)) · 已用 \(Format.percent(disk.usedFraction))"))
                .font(Theme.monoFont(9.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("可用空间 \(Format.bytes(max(0, disk.freeBytes)))"))
    }
}

// MARK: - Hero

/// The overview's one loud moment: the reclaimable figure, stated in plain
/// type above a ticked capacity ruler.
struct DashboardHeroCard: View {
    @EnvironmentObject private var app: AppState

    private var hasResult: Bool { (app.scanResult?.totalBytesFound ?? 0) > 0 }
    private var isScanning: Bool { app.phase == .scanning }

    private var usedFraction: Double {
        isScanning ? app.scanProgress.fraction : app.disk.usedFraction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
            figureRow.padding(.top, 18)
            descriptor.padding(.top, 6)
            rulerBlock.padding(.top, 20)
            buttonRow.padding(.top, 20)
            if hasResult && !isScanning {
                safetyNote.padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Status

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isScanning ? Theme.caution : Theme.accent)
                .frame(width: 6, height: 6)
            Text(L(isScanning ? "正在扫描" : (hasResult ? "扫描完成" : "尚未扫描")))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if isScanning {
                Text(Format.percent(app.scanProgress.fraction))
                    .font(Theme.monoFont(11))
                    .foregroundStyle(Theme.textTertiary)
            } else if hasResult {
                Text(L("\(app.scanResult?.totalItemCount ?? 0) 项 · 耗时 \(Format.compactDuration(app.scanResult?.duration ?? 0))"))
                    .font(Theme.monoFont(11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: Figure

    @ViewBuilder
    private var figureRow: some View {
        if isScanning {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.percent(app.scanProgress.fraction))
                    .font(Theme.figureFont(48, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("已完成"))
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else if hasResult, let found = app.scanResult?.totalBytesFound {
            let parts = Format.bytesParts(found)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(parts.number)
                    .font(Theme.figureFont(48, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(parts.unit)
                    .font(Theme.monoFont(20))
                    .foregroundStyle(Theme.textSecondary)
                Text(L("可清理"))
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            let parts = Format.bytesParts(max(0, app.disk.freeBytes))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(parts.number)
                    .font(Theme.figureFont(48, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(parts.unit)
                    .font(Theme.monoFont(20))
                    .foregroundStyle(Theme.textSecondary)
                Text(L("可用"))
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var descriptor: some View {
        if isScanning {
            Text(app.scanProgress.detail.isEmpty ? L("正在准备扫描…") : app.scanProgress.detail)
                .font(Theme.monoFont(12))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        } else if hasResult {
            Text(L("默认只选择安全项目，清理时移入废纸篓。"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        } else {
            Text(L("清理缓存、日志、旧备份与开发者垃圾。"))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Ruler

    private var rulerBlock: some View {
        VStack(spacing: 6) {
            CapacityRuler(fraction: usedFraction, height: 6)
            HStack {
                Text("0")
                Spacer()
                Text(L("已用 \(Format.percent(app.disk.usedFraction))"))
                Spacer()
                Text(Format.bytes(app.disk.totalBytes))
            }
            .font(Theme.monoFont(9.5))
            .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: Actions

    private var buttonRow: some View {
        HStack(spacing: 10) {
            if isScanning {
                Button {
                    app.cancelScan()
                } label: {
                    Text(L("取消扫描"))
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
            } else if hasResult {
                Button {
                    app.navigate(to: .smartScan)
                } label: {
                    Text(L("查看清理建议"))
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    app.startSmartScan()
                } label: {
                    Text(L("重新扫描"))
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button {
                    app.startSmartScan()
                } label: {
                    Text(L("开始扫描"))
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    app.navigate(to: .smartScan)
                } label: {
                    Text(L("查看扫描详情"))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var safetyNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 10, weight: .regular))
            Text(L("默认移入废纸篓，可随时恢复"))
                .font(.system(size: 11))
        }
        .foregroundStyle(Theme.textTertiary)
    }
}

// MARK: - Space breakdown

struct DashboardBreakdown: View {
    let metrics: [DashboardMetric]
    let hasResult: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "空间分类",
                          subtitle: hasResult ? "来自最近一次扫描" : "扫描后显示各类垃圾占用")
            if hasResult {
                stackedBar
                VStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                        row(metric, isLargest: index == largestIndex)
                        if metric.id != metrics.last?.id {
                            DividerLine()
                        }
                    }
                }
            } else {
                Text(L("运行一次扫描，查看缓存、日志、旧备份与开发者垃圾各占多少空间。"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var largestIndex: Int {
        metrics.enumerated()
            .max { $0.element.bytes < $1.element.bytes }?
            .offset ?? 0
    }

    private var total: Double {
        max(1, metrics.reduce(0) { $0 + Double($1.bytes) })
    }

    private var stackedBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == largestIndex ? Theme.accent : Theme.textPrimary.opacity(0.16))
                        .frame(width: max(2, proxy.size.width * CGFloat(Double(metric.bytes) / total) - 2))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 10)
    }

    private func row(_ metric: DashboardMetric, isLargest: Bool) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isLargest ? Theme.accent : Theme.textPrimary.opacity(0.22))
                .frame(width: 8, height: 8)
            Text(L(metric.title))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Text(Format.itemCount(metric.count))
                .font(Theme.monoFont(10.5))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 12)
            Text(Format.bytes(metric.bytes))
                .font(Theme.monoFont(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Quick tools

struct DashboardToolRow: View {
    let page: AppPage
    let title: String
    let subtitle: String
    let symbol: String

    @EnvironmentObject private var app: AppState
    @State private var hovering = false

    var body: some View {
        Button {
            app.navigate(to: page)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(title))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L(subtitle))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(hovering ? Theme.subtleFill : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .accessibilityLabel("\(title)，\(subtitle)")
    }
}

// MARK: - Clean history

struct DashboardHistoryCard: View {
    @EnvironmentObject private var settings: AppSettings

    private var recent: [CleanHistoryEntry] {
        Array(settings.history.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            if recent.isEmpty {
                Text(L("还没有清理记录。完成一次扫描后，这里会记录释放的空间。"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                ForEach(recent) { entry in
                    historyRow(entry)
                    if entry.id != recent.last?.id {
                        DividerLine()
                    }
                }
            }
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

    private func historyRow(_ entry: CleanHistoryEntry) -> some View {
        HStack(spacing: 12) {
            Text("+\(Format.bytes(entry.freedBytes))")
                .font(Theme.monoFont(12, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text(L("已释放"))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 12)
            Text(Format.itemCount(entry.itemCount))
                .font(Theme.monoFont(10.5))
                .foregroundStyle(Theme.textTertiary)
            Text(Format.dateTime(entry.date))
                .font(Theme.monoFont(10.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
}

// MARK: - Permission hint

struct DashboardPermissionBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Theme.caution)
                .frame(width: 2, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("授予完全磁盘访问权限"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("部分邮件附件与备份需要授权。列表中若没有 TidyMac，点击 + 添加。"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                AppPermissionActions.revealApplicationInFinder()
            } label: {
                Text(L("在 Finder 中显示"))
            }
            .buttonStyle(SoftButtonStyle(compact: true))
            .help("在 Finder 中显示 TidyMac，便于拖入完全磁盘访问列表")
            Button {
                FullDiskAccess.openPrivacySettings()
            } label: {
                Text(L("打开系统设置"))
            }
            .buttonStyle(SecondaryButtonStyle(compact: true))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("暂时隐藏")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
