import SwiftUI
import AppKit

struct SettingsPage: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings

    @State private var showResetAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "设置", subtitle: "清理偏好、排除项与安全策略") {
                    TagBadge(text: "v1.0.0", tone: .mint)
                }

                appearanceSection
                behaviorSection
                exclusionSection
                securitySection
                statisticsSection
                aboutSection

                Text("TidyMac 不会上传任何扫描数据。所有分析均在本机完成。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
            .padding(.bottom, 40)
            .frame(maxWidth: 900)
        }
        .alert("重置使用统计？", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { settings.resetStatistics() }
        } message: {
            Text("将清空累计释放空间、清理次数与历史记录，此操作不可撤销。")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsCard(title: "外观", symbol: "circle.lefthalf.filled", tone: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(AppAppearance.allCases) { option in
                        FilterPill(title: option.title,
                                   isSelected: settings.appearance == option,
                                   tone: .blue,
                                   softSelection: true) {
                            settings.appearance = option
                        }
                    }
                    Spacer(minLength: 8)
                    Text("跟随系统时会自动随 macOS 深色/浅色外观切换")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        settingsCard(title: "清理行为", symbol: "slider.horizontal.3", tone: .mint) {
            VStack(spacing: 0) {
                toggleRow("清理时移到废纸篓",
                          "最安全的方式，文件可在废纸篓中恢复。关闭后将永久删除。",
                          isOn: $settings.moveToTrash,
                          tone: .mint)
                DividerLine().padding(.vertical, 12)
                toggleRow("清理前再次确认",
                          "在执行清理前显示确认弹窗，并列出将删除的内容大小。",
                          isOn: $settings.confirmBeforeClean,
                          tone: .mint)
                if !settings.moveToTrash {
                    DividerLine().padding(.vertical, 12)
                    warningRow(symbol: "exclamationmark.triangle.fill",
                               text: "永久删除模式已开启：清理后的文件不会进入废纸篓。")
                }
            }
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String,
                           isOn: Binding<Bool>, tone: AccentTone) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.tint(tone))
                .controlSize(.small)
        }
    }

    // MARK: - Exclusions

    private var exclusionSection: some View {
        settingsCard(title: "排除列表", symbol: "hand.raised.fill", tone: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                Text("排除的文件或文件夹不会被智能扫描清理，也不会出现在结果中。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)

                if settings.excludedPaths.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "tray")
                            .foregroundStyle(Theme.textTertiary)
                        Text("暂无排除项")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.field)
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(settings.excludedPaths.enumerated()), id: \.element) { index, path in
                            if index > 0 { DividerLine() }
                            exclusionRow(path)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.field)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        addExclusion()
                    } label: {
                        Label("添加文件夹…", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle(tone: .orange, compact: true))

                    Button {
                        settings.addExclusion(HomePaths.url("Library/Caches").path)
                    } label: {
                        Label("添加示例：用户缓存", systemImage: "shippingbox")
                    }
                    .buttonStyle(GhostButtonStyle(tone: .orange))
                    .font(.system(size: 11.5))

                    Spacer()
                }
            }
        }
    }

    private func exclusionRow(_ path: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.orange.opacity(0.9))
            Text(displayPath(path))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button {
                settings.removeExclusion(path)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.subtleFill))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func displayPath(_ raw: String) -> String {
        let home = HomePaths.home.path
        if raw == home { return "~" }
        if raw.hasPrefix(home + "/") {
            return "~/" + String(raw.dropFirst(home.count + 1))
        }
        return raw
    }

    private func addExclusion() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.title = "选择要排除的文件或文件夹"
        panel.prompt = "排除"
        panel.message = "这些内容将不会被 TidyMac 扫描或清理。"
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                settings.addExclusion(url.path)
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        settingsCard(title: "权限与安全", symbol: "lock.shield.fill", tone: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((FullDiskAccess.hasAccess() ? Theme.mint : Theme.orange).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: FullDiskAccess.hasAccess() ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FullDiskAccess.hasAccess() ? Theme.mint : Theme.orange)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(FullDiskAccess.hasAccess() ? "完全磁盘访问权限已启用" : "建议开启完全磁盘访问权限")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(FullDiskAccess.hasAccess()
                             ? "TidyMac 可以完整扫描缓存、邮件附件与备份。"
                             : "未开启时部分目录无法读取，扫描结果可能不完整。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button("打开系统设置") { FullDiskAccess.openPrivacySettings() }
                        .buttonStyle(SecondaryButtonStyle(tone: .blue, compact: true))
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("列表中找不到 TidyMac？")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("点击列表下方的 +，选择 TidyMac.app；或点击「在 Finder 中显示」，把应用拖入列表。开启开关后请重新启动 TidyMac。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("在 Finder 中显示") { AppPermissionActions.revealApplicationInFinder() }
                        .buttonStyle(SecondaryButtonStyle(tone: .blue, compact: true))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.field)
                )

                DividerLine()

                VStack(alignment: .leading, spacing: 6) {
                    Label("安全保护始终开启", systemImage: "lock.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("系统目录、钥匙串、照片图库、邮件数据库、iCloud 文档等路径受到硬性保护，任何清理操作都会先通过安全策略校验。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DividerLine()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("在卸载器中显示系统应用")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text("仅用于查看系统组件占用；受 SIP 保护的系统应用无法卸载。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.showSystemApps)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Theme.mint)
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        settingsCard(title: "使用统计", symbol: "chart.bar.fill", tone: .purple) {
            HStack(spacing: 12) {
                statistic("累计释放", Format.bytes(settings.totalFreedBytes), "externaldrive.fill", .mint)
                statistic("清理次数", "\(settings.cleanCount) 次", "sparkles", .blue)
                statistic("上次清理", Format.date(settings.lastCleanDate), "clock.fill", .purple)
            }
            HStack {
                Text("统计数据仅保存在本机。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button("重置统计") { showResetAlert = true }
                    .buttonStyle(GhostButtonStyle(tone: .red))
                    .font(.system(size: 11.5))
            }
        }
    }

    private func statistic(_ title: String, _ value: String, _ symbol: String, _ tone: AccentTone) -> some View {
        HStack(spacing: 10) {
            ToneIcon(symbol: symbol, tone: tone, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.field)
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - About

    private var aboutSection: some View {
        HStack(spacing: 14) {
            AppBrandIcon(size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("TidyMac")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("轻净如羽，焕然一新  ·  v1.0.0  ·  macOS 14+")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text("Made for macOS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.cardElevated))
        }
        .qyPanel(padding: 16)
    }

    // MARK: - Cards

    private func settingsCard<Content: View>(title: String, symbol: String, tone: AccentTone,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                ToneIcon(symbol: symbol, tone: tone, size: 27)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            content()
        }
        .qyPanel(padding: 18)
    }

    private func warningRow(symbol: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.orange)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.orange.opacity(0.08))
        )
    }
}
