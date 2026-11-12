import SwiftUI

// MARK: - Idle

struct ScanIdleView: View {
    @EnvironmentObject private var app: AppState

    private struct ScanTarget: Identifiable {
        let id: String
        let title: String
        let symbol: String
    }

    private let targets: [ScanTarget] = [
        ScanTarget(id: "cache", title: "用户缓存", symbol: "shippingbox"),
        ScanTarget(id: "logs", title: "日志崩溃", symbol: "doc.text.magnifyingglass"),
        ScanTarget(id: "dev", title: "开发者缓存", symbol: "hammer"),
        ScanTarget(id: "browser", title: "浏览器数据", symbol: "safari"),
        ScanTarget(id: "mail", title: "邮件备份", symbol: "envelope")
    ]

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    Text(L("从一次扫描开始"))
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L("查清缓存、日志、旧备份与开发者垃圾占用的空间，只推荐可以安全清理的项目。"))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 430)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    Button {
                        app.startSmartScan()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                            Text(L("开始扫描"))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(tone: .mint))
                    .padding(.top, 24)

                    HStack(spacing: 22) {
                        ForEach(targets) { target in
                            HStack(spacing: 6) {
                                Image(systemName: target.symbol)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(width: 16)
                                Text(L(target.title))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 34)

                    Text(L("通常需要 10–30 秒 · 文件默认移入废纸篓"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 14)
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, Theme.pagePadding)
            }
        }
    }
}

// MARK: - Running

struct ScanRunningView: View {
    @EnvironmentObject private var app: AppState

    private struct RunningRow: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let state: Int // 0 waiting, 1 scanning, 2 done
    }

    private static let thresholds: [Double] = [0.08, 0.19, 0.33, 0.47, 0.61, 0.75, 0.88, 0.97]

    private var completedCount: Int {
        Self.thresholds.filter { $0 <= app.scanProgress.fraction }.count
    }

    private var rows: [RunningRow] {
        let categories = DemoData.categories
        let completed = completedCount
        return categories.enumerated().map { index, category in
            let state = index < completed ? 2 : (index == completed ? 1 : 0)
            return RunningRow(id: category.id, title: category.title,
                              symbol: category.symbol, state: state)
        }
    }

    private var fraction: Double {
        min(1, max(0, app.scanProgress.fraction))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 56) {
                    ringColumn
                    detailColumn
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.vertical, 16)
            }
        }
    }

    private var ringColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Format.percent(fraction))
                .font(Theme.figureFont(56))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(L("已完成"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            CapacityRuler(fraction: fraction, height: 6)
                .frame(width: 260)
                .padding(.top, 2)
            Text("\(completedCount) / \(rows.count)")
                .font(Theme.monoFont(10.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 280, alignment: .leading)
    }

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("正在扫描"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            Text(L(app.scanProgress.status))
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                Text(app.scanProgress.detail.isEmpty ? L("正在准备扫描位置…") : app.scanProgress.detail)
                    .font(Theme.monoFont(10.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(Theme.textTertiary)

            categoryPanel

            HStack(spacing: 12) {
                Button {
                    app.cancelScan()
                } label: {
                    Text(L("取消扫描"))
                }
                .buttonStyle(SecondaryButtonStyle(tone: .blue, compact: true))
                Text(L("已扫描的结果不会被保存"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryPanel: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(row.state == 0 ? Theme.textTertiary : Theme.textSecondary)
                        .frame(width: 18)
                    Text(L(row.title))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(row.state == 0 ? Theme.textTertiary : Theme.textPrimary)
                    Spacer(minLength: 8)
                    switch row.state {
                    case 2:
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    case 1:
                        Text(L("扫描中"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    default:
                        Text(L("等待"))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 32)
                if row.id != rows.last?.id {
                    DividerLine()
                }
            }
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: app.scanProgress.fraction)
    }
}

// MARK: - Results

struct ScanResultsView: View {
    let result: SmartScanResult

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var expanded: Set<String> = []
    @State private var showConfirm = false

    private var sections: [ScanGroupSection] {
        app.groupedCategories.map { ScanGroupSection(group: $0.group, categories: $0.categories) }
    }

    private var partiallySelected: Bool {
        guard let scan = app.scanResult, scan.totalItemCount > 0 else { return false }
        return scan.selectedCount > 0 && scan.selectedCount < scan.totalItemCount
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    summaryPanel
                    ForEach(sections) { section in
                        groupBlock(section)
                    }
                    footerNote
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 2)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScanActionBar(onClean: handleClean)
        }
        .onAppear(perform: expandInitialCategory)
        .alert("确认清理", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button(L(settings.moveToTrash ? "移到废纸篓" : "永久删除"), role: .destructive) {
                app.cleanSelected()
            }
        } message: {
            Text(L(alertMessage))
        }
    }

    private func expandInitialCategory() {
        guard expanded.isEmpty, let first = sections.first?.categories.first else { return }
        expanded.insert(first.id)
    }

    private func toggleExpanded(_ id: String) {
        withAnimation(.easeOut(duration: 0.18)) {
            if expanded.contains(id) {
                expanded.remove(id)
            } else {
                expanded.insert(id)
            }
        }
    }

    private func handleClean() {
        if settings.confirmBeforeClean {
            showConfirm = true
        } else {
            app.cleanSelected()
        }
    }

    private var alertMessage: String {
        var text = L("将清理 \(app.selectedCount) 项，预计释放 \(Format.bytes(app.selectedBytes))。")
        text += L(settings.moveToTrash
            ? "\n文件会移入废纸篓，可随时恢复。"
            : "\n文件将被永久删除，无法恢复。")
        if app.riskySelectedCount > 0 {
            text += L("\n注意：其中 \(app.riskySelectedCount) 项属于重要项目，可能影响应用或需要重新下载。")
        }
        return text
    }

    // MARK: Summary

    private var summaryPanel: some View {
        let parts = Format.bytesParts(result.totalBytesFound)
        let selectedParts = Format.bytesParts(app.selectedBytes)
        return HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("可清理空间"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(parts.number)
                        .font(Theme.figureFont(38))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text(parts.unit)
                        .font(Theme.monoFont(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(L("\(result.totalItemCount) 项 · 耗时 \(Format.compactDuration(result.duration))"))
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1, height: 52)

            VStack(alignment: .leading, spacing: 6) {
                Text(L("已选择"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(selectedParts.number)
                        .font(Theme.monoFont(22, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(app.hasSelection ? Theme.textPrimary : Theme.textTertiary)
                    Text(selectedParts.unit)
                        .font(Theme.monoFont(10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(L("\(app.selectedCount) 项"))
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 12) {
                Button {
                    app.setAllCategories(selected: !app.allSelected)
                } label: {
                    HStack(spacing: 8) {
                        Text(L(app.allSelected ? "取消全选" : "全选"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        SelectionCheck(isOn: app.allSelected, isPartial: partiallySelected, size: 18)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    app.startSmartScan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .medium))
                        Text(L("重新扫描"))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(tone: .mint, compact: true))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: Groups

    @ViewBuilder
    private func groupBlock(_ section: ScanGroupSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L(section.group.title))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("\(section.categories.count) 类 · \(section.itemCount) 项"))
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(Format.bytes(section.totalBytes))
                    .font(Theme.monoFont(11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(section.categories) { category in
                    ScanCategoryPanel(category: category,
                                      isExpanded: expanded.contains(category.id)) {
                        toggleExpanded(category.id)
                    }
                }
            }
        }
    }

    private var footerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 10))
            Text(L("重要项目默认不勾选，清理前会再次校验。"))
                .font(.system(size: 10.5))
        }
        .foregroundStyle(Theme.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

struct ScanCategoryPanel: View {
    let category: ScanCategory
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    @EnvironmentObject private var app: AppState
    @State private var hovering = false

    private var highestSafety: SafetyLevel? {
        if category.items.contains(where: { $0.safety == .risky }) { return .risky }
        if category.items.contains(where: { $0.safety == .caution }) { return .caution }
        return nil
    }

    private var attentionCount: Int {
        category.items.filter { $0.safety != .safe }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded && !category.items.isEmpty {
                DividerLine().padding(.horizontal, 16)
                VStack(spacing: 0) {
                    ForEach(category.items) { item in
                        ScanItemLine(categoryID: category.id, item: item)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(hovering || isExpanded ? Theme.strokeStrong : Theme.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .onHover { hovering = $0 }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ToneIcon(symbol: category.symbol, tone: category.tone, size: 17)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(L(category.title))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if let safety = highestSafety, attentionCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 9, weight: .medium))
                            Text(L("\(attentionCount) 项需注意"))
                                .font(.system(size: 10.5))
                        }
                        .foregroundStyle(Theme.tint(safety.tone))
                    }
                }
                Text(L(category.subtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.bytes(category.totalBytes))
                    .font(Theme.monoFont(12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(Format.itemCount(category.itemCount))
                    .font(Theme.monoFont(10))
                    .foregroundStyle(Theme.textTertiary)
            }

            Button {
                app.toggleCategory(category.id)
            } label: {
                SelectionCheck(isOn: category.isAllSelected,
                               isPartial: category.isPartiallySelected,
                               tone: category.tone,
                               size: 18)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L(category.isAllSelected ? "取消选择此类别" : "全选此类别"))

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .frame(width: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpanded() }
    }
}

struct ScanItemLine: View {
    let categoryID: String
    let item: ScanItem

    @EnvironmentObject private var app: AppState
    @State private var hovering = false

    private var pathText: String {
        item.displayDetail ?? HomePaths.relativePath(item.primaryURL)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                app.toggleItem(categoryID: categoryID, itemID: item.id)
            } label: {
                SelectionCheck(isOn: item.isSelected, size: 17)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(L(item.name))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(item.isSelected ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                    if item.safety == .risky {
                        Text(L("默认不选"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.negative)
                    }
                }
                Text(L(pathText))
                    .font(Theme.monoFont(10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            excludeButton

            SafetyBadge(safety: item.safety, compact: true)

            Text(Format.bytes(item.byteCount))
                .font(Theme.monoFont(11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(hovering ? Theme.subtleFill : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    /// Revealed on row hover. The slot is always laid out so the row never jumps
    /// when the pointer moves in and out.
    private var excludeButton: some View {
        Button {
            app.excludeItem(categoryID: categoryID, itemID: item.id)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "nosign")
                    .font(.system(size: 9, weight: .medium))
                Text(L("排除"))
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("加入排除列表，以后不再扫描和清理"))
        .opacity(hovering ? 1 : 0)
        .allowsHitTesting(hovering)
        .accessibilityHidden(!hovering)
        .animation(.easeOut(duration: 0.14), value: hovering)
    }
}

/// Floating confirmation shown after excluding a scan result. It stays visible
/// for a few seconds so the exclusion can be undone without opening Settings.
struct ScanExclusionBanner: View {
    let notice: ScanExclusionNotice
    var onUndo: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "nosign")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("已排除「%@」", notice.itemName))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(L("已加入排除列表，以后扫描和清理都会跳过。"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button(action: onUndo) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .medium))
                    Text(L("撤销"))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(GhostButtonStyle(tone: .orange))
            .help(L("撤销排除"))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.field))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.cardElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 4)
    }
}

struct ScanActionBar: View {
    let onClean: () -> Void

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("已选 \(app.selectedCount) 项 · \(Format.bytes(app.selectedBytes))"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(app.hasSelection ? Theme.textPrimary : Theme.textSecondary)
                Text(L(settings.moveToTrash ? "将移入废纸篓，可随时恢复" : "将永久删除，无法恢复"))
                    .font(.system(size: 11))
                    .foregroundStyle(settings.moveToTrash ? Theme.textTertiary : Theme.negative)
            }

            if app.riskySelectedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 9, weight: .medium))
                    Text(L("含 \(app.riskySelectedCount) 项重要项目"))
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Theme.caution)
            }

            Spacer(minLength: 12)

            Button(action: onClean) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                    Text(L("清理 \(Format.bytes(app.selectedBytes))"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(tone: .mint))
            .disabled(!app.hasSelection)
            .opacity(app.hasSelection ? 1 : 0.45)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 12)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
        .animation(.easeOut(duration: 0.15), value: app.selectedCount)
    }
}

// MARK: - Cleaning

struct ScanCleaningView: View {
    @EnvironmentObject private var app: AppState

    private var fraction: Double {
        min(1, max(0, app.cleanProgress.fraction))
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                VStack(spacing: 10) {
                    Text(Format.percent(fraction))
                        .font(Theme.figureFont(56))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text(L("清理中"))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    CapacityRuler(fraction: fraction, height: 6)
                        .frame(width: 320)
                        .padding(.top, 4)
                }

                Text(app.cleanProgress.status.isEmpty ? L("正在清理所选项目…") : app.cleanProgress.status)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                Text(L("已选 \(app.selectedCount) 项 · \(Format.bytes(app.selectedBytes))"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                    Text(L("清理过程中请不要关闭应用"))
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Theme.caution)
                .padding(.top, 18)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: proxy.size.height)
            .padding(.horizontal, Theme.pagePadding)
        }
    }
}

// MARK: - Finished

struct ScanFinishedView: View {
    @EnvironmentObject private var app: AppState

    private var report: CleanReport { app.cleanReport ?? .empty }

    private var parts: (number: String, unit: String) {
        Format.bytesParts(report.freedBytes)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    Text(L("清理完成"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("+" + parts.number)
                            .font(Theme.figureFont(64))
                            .monospacedDigit()
                            .foregroundStyle(Theme.accent)
                        Text(parts.unit)
                            .font(Theme.monoFont(22, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 6)

                    Text(L("已释放空间"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)

                    Text(metaLine)
                        .font(Theme.monoFont(10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 14)

                    if !report.failures.isEmpty {
                        failuresCard
                            .padding(.top, 20)
                    }

                    HStack(spacing: 10) {
                        Button {
                            app.dismissCleanSummary()
                        } label: {
                            Text(L("完成"))
                        }
                        .buttonStyle(PrimaryButtonStyle(tone: .mint))

                        Button {
                            app.startSmartScan()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10, weight: .medium))
                                Text(L("再次扫描"))
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle(tone: .mint))
                    }
                    .padding(.top, 28)

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, Theme.pagePadding)
            }
        }
    }

    private var metaLine: String {
        var bits = [L("已清理 \(report.removedCount) 项"),
                    L(report.movedToTrash ? "已移入废纸篓" : "已永久删除"),
                    Format.dateTime(report.completedAt)]
        if !report.failures.isEmpty {
            bits.append(L("\(report.failures.count) 个文件未能清理"))
        }
        return bits.joined(separator: " · ")
    }

    private var failuresCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .medium))
                Text(L("\(report.failures.count) 个文件未能清理"))
                    .font(.system(size: 11.5, weight: .medium))
                Spacer(minLength: 8)
                Text(L("可能权限不足或文件正被占用"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
            .foregroundStyle(Theme.caution)

            ForEach(report.failures.prefix(5)) { failure in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(failure.path))
                            .font(Theme.monoFont(10))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(L(failure.reason))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 560)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.caution.opacity(0.30), lineWidth: 1)
        )
    }
}

// MARK: - Empty results

struct ScanEmptyResultsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            EmptyStateView(symbol: "sparkles",
                           title: "没有发现可清理的垃圾",
                           message: "Mac 已经很干净了。若希望扫描更多位置，请在设置中授予完全磁盘访问权限。",
                           actionTitle: "重新扫描") {
                app.startSmartScan()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Theme.pagePadding)
    }
}

// MARK: - Helpers

private struct ScanGroupSection: Identifiable {
    let group: CleanupGroup
    let categories: [ScanCategory]

    var id: String { group.rawValue }
    var totalBytes: Int64 { categories.reduce(0) { $0 + $1.totalBytes } }
    var itemCount: Int { categories.reduce(0) { $0 + $1.itemCount } }
}
