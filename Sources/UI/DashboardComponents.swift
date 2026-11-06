import SwiftUI

// MARK: - Header accessory (shared by 总览 / 智能扫描)

/// Compact disk summary shown at the trailing edge of `PageHeader`.
struct QYAvailableSpacePill: View {
    let disk: DiskInfo

    private var barTone: AccentTone {
        disk.usedFraction > 0.9 ? .orange : .mint
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text(L("可用空间"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(Format.bytes(max(0, disk.freeBytes)))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mint)
            }
            StorageBar(usedFraction: disk.usedFraction, tone: barTone, height: 5)
                .frame(width: 176)
            Text(L("共 \(Format.bytes(disk.totalBytes)) · 已用 \(Format.percent(disk.usedFraction))"))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.card.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("可用空间 \(Format.bytes(max(0, disk.freeBytes)))"))
    }
}

// MARK: - Hero

/// The large, glowing "smart scan" panel that anchors the overview page.
struct DashboardHeroCard: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var breathing = false

    private var hasResult: Bool { (app.scanResult?.totalBytesFound ?? 0) > 0 }
    private var isScanning: Bool { app.phase == .scanning }

    private var ringProgress: Double {
        if isScanning { return app.scanProgress.fraction }
        if hasResult { return 1 }
        return app.disk.freeFraction
    }

    private var ringTone: AccentTone {
        isScanning ? .blue : .mint
    }

    var body: some View {
        HStack(alignment: .center, spacing: 26) {
            ring
            textColumn
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { heroBackground }
        .overlay { heroDecorations }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [Theme.mint.opacity(0.34),
                                            Theme.blue.opacity(0.16),
                                            Theme.stroke],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: Theme.mint.opacity(0.10), radius: 28, x: 0, y: 14)
        .onAppear {
            guard !settings.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    // MARK: Background / decoration

    private var heroBackground: some View {
        ZStack {
            Theme.heroGradient
            Circle()
                .fill(Theme.mint.opacity(0.20))
                .frame(width: 340, height: 340)
                .blur(radius: 110)
                .offset(x: -260, y: 95)
            Circle()
                .fill(Theme.blue.opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: 300, y: -120)
            Circle()
                .fill(Theme.purple.opacity(0.10))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: 110, y: 150)
        }
        .allowsHitTesting(false)
    }

    private var heroDecorations: some View {
        ZStack {
            Image(systemName: "wind")
                .font(.system(size: 168, weight: .ultraLight))
                .foregroundStyle(Theme.mint.opacity(0.075))
                .rotationEffect(.degrees(-12))
                .offset(x: 262, y: 30)
            Image(systemName: "sparkles")
                .font(.system(size: 23, weight: .light))
                .foregroundStyle(Theme.mint.opacity(breathing ? 0.45 : 0.20))
                .offset(x: 168, y: -92)
            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.blue.opacity(breathing ? 0.38 : 0.16))
                .offset(x: 332, y: 92)
        }
        .allowsHitTesting(false)
    }

    // MARK: Ring

    private var ring: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.mint.opacity(0.16),
                              style: StrokeStyle(lineWidth: 1, dash: [1.5, 8]))
                .frame(width: 202, height: 202)
                .rotationEffect(.degrees(breathing ? 7 : -7))
            Circle()
                .fill(Theme.tint(ringTone).opacity(breathing ? 0.13 : 0.05))
                .frame(width: 148, height: 148)
                .blur(radius: 34)
            ProgressRing(progress: ringProgress, lineWidth: 15, size: 188, tone: ringTone)
            ringCenter
        }
        .frame(width: 202, height: 202)
        .animation(.easeInOut(duration: 0.45), value: ringProgress)
    }

    @ViewBuilder
    private var ringCenter: some View {
        if isScanning {
            VStack(spacing: 4) {
                Text(Format.percent(app.scanProgress.fraction))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(LinearGradient(colors: [Theme.blue, Theme.mint],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing))
                Text(L("扫描中"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else if app.scanResult != nil && hasResult {
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Format.bytesParts(app.scanResult?.totalBytesFound ?? 0).number)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Theme.brandGradient)
                    Text(Format.bytesParts(app.scanResult?.totalBytesFound ?? 0).unit)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.mint)
                }
                Text(L("可清理"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
        } else {
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Format.bytesParts(app.disk.freeBytes).number)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(Theme.textPrimary)
                    Text(Format.bytesParts(app.disk.freeBytes).unit)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.mint)
                }
                Text(L("可用空间"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: Text column

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            tag
            titleView.padding(.top, 10)
            subtitleView.padding(.top, 6)
            if isScanning {
                StorageBar(usedFraction: app.scanProgress.fraction, tone: .blue, height: 4)
                    .frame(width: 330)
                    .padding(.top, 12)
            }
            buttonRow.padding(.top, 16)
            if hasResult && !isScanning {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 9.5))
                    Text(L("默认移入废纸篓，可随时恢复"))
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tag: some View {
        let tone: AccentTone = isScanning ? .blue : .mint
        let label = isScanning ? "正在扫描" : (hasResult ? "扫描完成" : "智能扫描")
        let symbol = isScanning ? "sparkles" : (hasResult ? "checkmark.seal.fill" : "sparkles")
        return HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .bold))
            Text(L(label))
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
            if isScanning {
                Circle()
                    .fill(Theme.blue)
                    .frame(width: 5, height: 5)
                    .opacity(breathing ? 1 : 0.3)
            }
        }
        .foregroundStyle(Theme.tint(tone))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.tint(tone).opacity(0.10)))
        .overlay(Capsule().strokeBorder(Theme.tint(tone).opacity(0.20), lineWidth: 0.8))
    }

    @ViewBuilder
    private var titleView: some View {
        if isScanning {
            Text(L(app.scanProgress.status))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } else if hasResult, let found = app.scanResult?.totalBytesFound {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(L("发现"))
                    .foregroundStyle(Theme.textPrimary)
                Text(Format.bytes(found))
                    .foregroundStyle(Theme.brandGradient)
                Text(L("可清理"))
                    .foregroundStyle(Theme.textPrimary)
            }
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            Text(L("让 Mac 轻净如羽"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        if isScanning {
            HStack(spacing: 7) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.textTertiary)
                Text(app.scanProgress.detail.isEmpty ? L("正在准备扫描…") : app.scanProgress.detail)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else if hasResult {
            Text(L("共 \(app.scanResult?.totalItemCount ?? 0) 项 · 耗时 \(Format.compactDuration(app.scanResult?.duration ?? 0)) · 默认只选择安全项目"))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(L("一次扫描，找出缓存、日志、旧备份与开发者垃圾，让空间重新流动起来。"))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttonRow: some View {
        HStack(spacing: 10) {
            if isScanning {
                Button {
                    app.cancelScan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(L("取消扫描"))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(tone: .blue))
            } else if hasResult {
                Button {
                    app.navigate(to: .smartScan)
                } label: {
                    HStack(spacing: 6) {
                        Text(L("查看清理建议"))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tone: .mint))
                Button {
                    app.startSmartScan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L("重新扫描"))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(tone: .mint))
            } else {
                Button {
                    app.startSmartScan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L("开始扫描"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tone: .mint))
                Button {
                    app.navigate(to: .smartScan)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L("查看扫描详情"))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(tone: .mint))
            }
        }
    }
}

// MARK: - Quick tools

struct DashboardQuickToolCard: View {
    let page: AppPage
    let title: String
    let subtitle: String
    let symbol: String
    let tone: AccentTone

    @EnvironmentObject private var app: AppState

    var body: some View {
        Button {
            app.navigate(to: page)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ToneIcon(symbol: symbol, tone: tone, size: 40)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.subtleFill))
                        .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                Spacer(minLength: 12)
                Text(L(title))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L(subtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 92)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverLift()
        .frame(maxWidth: .infinity)
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
        Group {
            if recent.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.mint.opacity(0.08)).frame(width: 34, height: 34)
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.mint.opacity(0.8))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("还没有清理记录"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(L("完成一次智能扫描后，这里会显示你释放的空间。"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.card.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { entry in
                        historyRow(entry)
                        if entry.id != recent.last?.id {
                            DividerLine().padding(.horizontal, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.card.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
            }
        }
    }

    private func historyRow(_ entry: CleanHistoryEntry) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.mint.opacity(0.10)).frame(width: 30, height: 30)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.mint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("释放 \(Format.bytes(entry.freedBytes))"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(Format.dateTime(entry.date))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 8)
            Text(Format.itemCount(entry.itemCount))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Permission hint

struct DashboardPermissionBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.orange.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("授予完全磁盘访问权限"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("部分邮件附件与备份需要授权。列表中若没有 TidyMac，点击 + 添加。"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                AppPermissionActions.revealApplicationInFinder()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text(L("在 Finder 中显示"))
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.orange)
            }
            .buttonStyle(.plain)
            .help("在 Finder 中显示 TidyMac，便于拖入完全磁盘访问列表")
            Button {
                FullDiskAccess.openPrivacySettings()
            } label: {
                Text(L("打开系统设置"))
            }
            .buttonStyle(SecondaryButtonStyle(tone: .orange, compact: true))
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("暂时隐藏")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.orange.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.orange.opacity(0.20), lineWidth: 1)
        )
    }
}
