import SwiftUI

// MARK: - Idle

struct ScanIdleView: View {
    @EnvironmentObject private var app: AppState
    @State private var breathing = false

    private struct ScanTarget: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let tone: AccentTone
    }

    private let targets: [ScanTarget] = [
        ScanTarget(id: "cache", title: "用户缓存", symbol: "shippingbox.fill", tone: .mint),
        ScanTarget(id: "logs", title: "日志崩溃", symbol: "doc.text.magnifyingglass", tone: .blue),
        ScanTarget(id: "dev", title: "开发者缓存", symbol: "hammer.fill", tone: .purple),
        ScanTarget(id: "browser", title: "浏览器数据", symbol: "safari.fill", tone: .teal),
        ScanTarget(id: "mail", title: "邮件备份", symbol: "envelope.fill", tone: .pink)
    ]

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 14)
                    ring
                    Text(L("开始智能扫描"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 20)
                    Text(L("TidyMac 会检查缓存、日志、开发者构建缓存、浏览器数据与旧备份，\n只推荐可以安全清理的项目，并默认移入废纸篓。"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 9)
                    HStack(spacing: 14) {
                        Button {
                            app.startSmartScan()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(L("开始智能扫描"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(tone: .mint))
                        Text(L("通常只需 10 – 30 秒"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.top, 20)
                    targetsGrid
                        .padding(.top, 26)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 9.5))
                        Text(L("所有清理均经过安全校验，默认移入废纸篓，可随时恢复。"))
                            .font(.system(size: 10.5))
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 20)
                    Spacer(minLength: 14)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(Theme.mint.opacity(0.07))
                .frame(width: 240, height: 240)
                .blur(radius: 48)
            Circle()
                .strokeBorder(Theme.mint.opacity(0.15),
                              style: StrokeStyle(lineWidth: 1, dash: [1.5, 9]))
                .frame(width: 208, height: 208)
                .rotationEffect(.degrees(breathing ? 7 : -7))
            ProgressRing(progress: 0, lineWidth: 12, size: 170, tone: .mint, showsGlow: false)
            VStack(spacing: 8) {
                Image(systemName: "wind")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Theme.brandGradient)
                Text(L("准备就绪"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 224, height: 224)
    }

    private var targetsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
            ForEach(targets) { target in
                VStack(spacing: 8) {
                    ToneIcon(symbol: target.symbol, tone: target.tone, size: 30)
                    Text(L(target.title))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.card.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: 760)
    }
}

// MARK: - Running

struct ScanRunningView: View {
    @EnvironmentObject private var app: AppState
    @State private var rotating = false

    private struct RunningRow: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let tone: AccentTone
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
                              symbol: category.symbol, tone: category.tone, state: state)
        }
    }

    private var fraction: Double {
        min(1, max(0, app.scanProgress.fraction))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                HStack(alignment: .center, spacing: 46) {
                    ringColumn
                    detailColumn
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                rotating = true
            }
        }
    }

    private var ringColumn: some View {
        ZStack {
            Circle()
                .stroke(Theme.angular(.blue).opacity(0.16), lineWidth: 20)
                .frame(width: 268, height: 268)
                .blur(radius: 18)
                .rotationEffect(.degrees(rotating ? 360 : 0))
            Circle()
                .fill(Theme.blue.opacity(0.09))
                .frame(width: 250, height: 250)
                .blur(radius: 46)
            ProgressRing(progress: fraction, lineWidth: 16, size: 232, tone: .mint)
            VStack(spacing: 4) {
                Text(Format.percent(fraction))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LinearGradient(colors: [Theme.mint, Theme.blue],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing))
                Text(L("已完成"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 300, height: 300)
    }

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                ScanPulseDot(color: Theme.blue, size: 5)
                Text(L("正在扫描"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(Theme.blue)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.blue.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Theme.blue.opacity(0.20), lineWidth: 0.8))

            Text(L(app.scanProgress.status))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9.5))
                Text(app.scanProgress.detail.isEmpty ? L("正在准备扫描位置…") : app.scanProgress.detail)
                    .font(.system(size: 11.5, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(Theme.textTertiary)

            StorageBar(usedFraction: fraction, tone: .blue, height: 5)
                .frame(width: 340)

            categoryPanel

            HStack(spacing: 12) {
                Button {
                    app.cancelScan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(L("取消扫描"))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(tone: .blue, compact: true))
                Text(L("已扫描的结果不会被保存"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryPanel: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.tint(row.tone).opacity(row.state == 0 ? 0.45 : 1))
                        .frame(width: 18)
                    Text(L(row.title))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(row.state == 0 ? Theme.textTertiary : Theme.textPrimary)
                    Spacer(minLength: 8)
                    switch row.state {
                    case 2:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.mint)
                    case 1:
                        HStack(spacing: 5) {
                            ScanPulseDot(color: Theme.blue, size: 5)
                            Text(L("扫描中"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.blue)
                        }
                    default:
                        Text(L("等待"))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(row.state == 1 ? Theme.blue.opacity(0.06) : Color.clear)
                .overlay(alignment: .leading) {
                    if row.state == 1 {
                        Rectangle()
                            .fill(Theme.blue)
                            .frame(width: 2)
                    }
                }
                if row.id != rows.last?.id {
                    DividerLine().padding(.leading, 40)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.card.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.3), value: app.scanProgress.fraction)
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
                VStack(alignment: .leading, spacing: 16) {
                    summaryPanel
                    ForEach(sections) { section in
                        groupBlock(section)
                    }
                    footerNote
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 2)
                .padding(.bottom, 26)
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
        withAnimation(.easeInOut(duration: 0.22)) {
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
        return HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L("扫描完成 · 可清理空间"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(Theme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(L(parts.number))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.brandGradient)
                    Text(L(parts.unit))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.mint)
                }
                Text(L("共 \(result.totalItemCount) 项 · 耗时 \(Format.compactDuration(result.duration))"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text(L("已选择"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(L(selectedParts.number))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(app.hasSelection ? Theme.textPrimary : Theme.textTertiary)
                    Text(L(selectedParts.unit))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(Format.itemCount(app.selectedCount))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    app.setAllCategories(selected: !app.allSelected)
                } label: {
                    HStack(spacing: 7) {
                        Text(L(app.allSelected ? "取消全选" : "全选"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        SelectionCheck(isOn: app.allSelected, isPartial: partiallySelected, size: 19)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    app.startSmartScan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L("重新扫描"))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(tone: .mint, compact: true))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Theme.cardElevated, Theme.card],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
    }

    // MARK: Groups

    @ViewBuilder
    private func groupBlock(_ section: ScanGroupSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L(section.group.title))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("\(section.categories.count) 类 · \(section.itemCount) 项"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(Format.bytes(section.totalBytes))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mint)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

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
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 9.5))
            Text(L("勾选的项目会经过安全校验后再清理，标记为「重要」的项目默认不勾选。"))
                .font(.system(size: 10.5))
        }
        .foregroundStyle(Theme.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
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
                .padding(.vertical, 5)
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
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ToneIcon(symbol: category.symbol, tone: category.tone, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(L(category.title))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if let safety = highestSafety, attentionCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: safety.symbol)
                                .font(.system(size: 8, weight: .bold))
                            Text(L("\(attentionCount) 项需注意"))
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundStyle(Theme.tint(safety.tone))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Theme.tint(safety.tone).opacity(0.10)))
                        .overlay(Capsule().strokeBorder(Theme.tint(safety.tone).opacity(0.16), lineWidth: 0.5))
                    }
                }
                Text(L(category.subtitle))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.bytes(category.totalBytes))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(Format.itemCount(category.itemCount))
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
            }

            Button {
                app.toggleCategory(category.id)
            } label: {
                SelectionCheck(isOn: category.isAllSelected,
                               isPartial: category.isPartiallySelected,
                               tone: category.tone,
                               size: 20)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L(category.isAllSelected ? "取消选择此类别" : "全选此类别"))

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
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
        HStack(spacing: 11) {
            Button {
                app.toggleItem(categoryID: categoryID, itemID: item.id)
            } label: {
                SelectionCheck(isOn: item.isSelected, size: 18)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(L(item.name))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.isSelected ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                    if item.safety == .risky {
                        Text(L("默认不选"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.red.opacity(0.9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.red.opacity(0.10)))
                    }
                }
                Text(L(pathText))
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            excludeButton

            SafetyBadge(safety: item.safety, compact: true)

            Text(Format.bytes(item.byteCount))
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 62, alignment: .trailing)
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
                    .font(.system(size: 9, weight: .semibold))
                Text(L("排除"))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(Theme.cardElevated))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .help(L("加入排除列表，以后不再扫描和清理"))
        .opacity(hovering ? 1 : 0)
        .allowsHitTesting(hovering)
        .accessibilityHidden(!hovering)
        .animation(.easeInOut(duration: 0.14), value: hovering)
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
            ToneIcon(symbol: "nosign", tone: .orange, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("已排除「%@」", notice.itemName))
                    .font(.system(size: 12.5, weight: .semibold))
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
                        .font(.system(size: 9, weight: .semibold))
                    Text(L("撤销"))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(GhostButtonStyle(tone: .orange))
            .help(L("撤销排除"))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.field))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.strokeStrong, lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 16, x: 0, y: 7)
    }
}

struct ScanActionBar: View {
    let onClean: () -> Void

    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.mint.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.mint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L("已选 \(app.selectedCount) 项 · \(Format.bytes(app.selectedBytes))"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(app.hasSelection ? Theme.textPrimary : Theme.textSecondary)
                Text(L(settings.moveToTrash ? "将移入废纸篓，可随时恢复" : "将永久删除，无法恢复"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(settings.moveToTrash ? Theme.textTertiary : Theme.orange)
            }

            if app.riskySelectedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(L("含 \(app.riskySelectedCount) 项重要项目"))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.orange.opacity(0.10)))
                .overlay(Capsule().strokeBorder(Theme.orange.opacity(0.16), lineWidth: 0.5))
            }

            Spacer(minLength: 12)

            Button(action: onClean) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text(L("清理 \(Format.bytes(app.selectedBytes))"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(tone: .mint))
            .disabled(!app.hasSelection)
            .opacity(app.hasSelection ? 1 : 0.45)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Theme.background.opacity(0.30), Theme.background.opacity(0.94)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.stroke).frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: app.selectedCount)
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
                ZStack {
                    Circle()
                        .fill(Theme.mint.opacity(0.08))
                        .frame(width: 280, height: 280)
                        .blur(radius: 56)
                    Circle()
                        .strokeBorder(Theme.mint.opacity(0.14),
                                      style: StrokeStyle(lineWidth: 1, dash: [1.5, 9]))
                        .frame(width: 244, height: 244)
                    ProgressRing(progress: max(0.012, fraction), lineWidth: 16, size: 214, tone: .mint)
                    VStack(spacing: 4) {
                        Text(Format.percent(fraction))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.brandGradient)
                        Text(L("清理中"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 280, height: 280)

                Text(app.cleanProgress.status.isEmpty ? "正在清理所选项目…" : app.cleanProgress.status)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)

                Text(L("已选 \(app.selectedCount) 项 · \(Format.bytes(app.selectedBytes))"))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 7)

                StorageBar(usedFraction: fraction, tone: .mint, height: 5)
                    .frame(width: 320)
                    .padding(.top, 16)

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9.5))
                    Text(L("清理过程中请不要关闭应用"))
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Theme.orange.opacity(0.85))
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
                ZStack {
                    ScanCelebration()
                    VStack(spacing: 0) {
                        Spacer(minLength: 12)
                        successBadge
                        Text(L("清理完成"))
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 20)
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(L(parts.number))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.brandGradient)
                            Text(L(parts.unit))
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.mint)
                        }
                        .padding(.top, 2)
                        Text(L("空间已释放"))
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 2)

                        HStack(spacing: 8) {
                            chip("checkmark.circle.fill", L("已清理 \(report.removedCount) 项"), .mint)
                            chip("trash.fill", report.movedToTrash ? "已移入废纸篓" : "已永久删除",
                                 report.movedToTrash ? .blue : .orange)
                            chip("clock.fill", Format.dateTime(report.completedAt), .teal)
                        }
                        .padding(.top, 16)

                        if !report.failures.isEmpty {
                            failuresCard
                                .padding(.top, 18)
                        }

                        HStack(spacing: 10) {
                            Button {
                                app.dismissCleanSummary()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(L("完成"))
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(tone: .mint))
                            Button {
                                app.startSmartScan()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(L("再次扫描"))
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle(tone: .mint))
                        }
                        .padding(.top, 26)
                        Spacer(minLength: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                    .padding(.horizontal, Theme.pagePadding)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var successBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.mint.opacity(0.10))
                .frame(width: 92, height: 92)
            Circle()
                .strokeBorder(Theme.mint.opacity(0.22), lineWidth: 1)
                .frame(width: 112, height: 112)
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.brandGradient)
        }
    }

    private func chip(_ symbol: String, _ text: String, _ tone: AccentTone) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 9))
            Text(L(text))
                .font(.system(size: 10.5, weight: .medium))
        }
        .foregroundStyle(Theme.tint(tone))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.tint(tone).opacity(0.10)))
        .overlay(Capsule().strokeBorder(Theme.tint(tone).opacity(0.16), lineWidth: 0.5))
    }

    private var failuresCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text(L("\(report.failures.count) 个文件未能清理"))
                    .font(.system(size: 11.5, weight: .semibold))
                Spacer(minLength: 8)
                Text(L("可能权限不足或文件正被占用"))
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            .foregroundStyle(Theme.orange)

            ForEach(report.failures.prefix(5)) { failure in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.orange.opacity(0.75))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L(failure.path))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(L(failure.reason))
                            .font(.system(size: 9.5))
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.orange.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.orange.opacity(0.18), lineWidth: 1)
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

// MARK: - Shared bits

struct ScanPulseDot: View {
    let color: Color
    var size: CGFloat = 6

    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(pulsing ? 1 : 0.35)
            .scaleEffect(pulsing ? 1.15 : 0.9)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

struct ScanCelebration: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(Theme.mint.opacity(0.26 - Double(index) * 0.06), lineWidth: 1.2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(animate ? 2.0 : 0.85)
                    .opacity(animate ? 0 : 0.75)
                    .animation(.easeOut(duration: 2.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.87),
                               value: animate)
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
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
