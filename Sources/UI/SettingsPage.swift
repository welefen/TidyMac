import SwiftUI
import AppKit

struct SettingsPage: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updates: UpdateManager

    @State private var showResetAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "设置", subtitle: "清理偏好、排除项与安全策略")

                appearanceSection
                languageSection
                updatesSection
                behaviorSection
                exclusionSection
                securitySection
                statisticsSection
                aboutSection

                Text(L("扫描与清理分析均在本机完成；仅上报匿名功能统计，不含任何文件路径或内容。"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
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
            Text(L("将清空累计释放空间、清理次数与历史记录，此操作不可撤销。"))
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsCard(title: "外观") {
            HStack(alignment: .center, spacing: 10) {
                ForEach(AppAppearance.allCases) { option in
                    FilterPill(title: option.title,
                               isSelected: settings.appearance == option) {
                        settings.appearance = option
                    }
                }
                Spacer(minLength: 12)
                Text(L("跟随系统时会自动随 macOS 深色/浅色外观切换"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        settingsCard(title: "语言") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    ForEach(AppLanguage.allCases) { option in
                        FilterPill(title: option.title,
                                   isSelected: settings.language == option) {
                            guard settings.language != option else { return }
                            settings.applyLanguage(option)
                            restartForLanguageChange()
                        }
                    }
                    Spacer(minLength: 12)
                    Text(L("跟随系统时使用 macOS 首选语言；不支持的语言会自动使用英文。"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                Text(L("切换语言后应用会自动重新启动。"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func restartForLanguageChange() {
        let appPath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.7; /usr/bin/open -n '\(appPath)'"]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Updates

    private var updatesSection: some View {
        settingsCard(title: "更新") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TidyMac \(updates.currentVersion)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(updates.statusText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(updateStatusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                if case .ready = updates.phase {
                    Button(updateActionTitle) {
                        updates.installDownloadedUpdate()
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                } else {
                    Button(updateActionTitle) {
                        Task { await updates.check(manual: true) }
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    .disabled(updateActionDisabled)
                }
            }
        }
    }

    private var updateActionTitle: String {
        switch updates.phase {
        case .checking:
            return L("检查中…")
        case .available, .downloading:
            return L("下载中…")
        case .ready:
            return L("立即安装")
        case .installing:
            return L("正在安装…")
        default:
            return L("检查更新")
        }
    }

    private var updateActionDisabled: Bool {
        switch updates.phase {
        case .checking, .available, .downloading, .installing:
            return true
        default:
            return false
        }
    }

    private var updateStatusColor: Color {
        if case .failed = updates.phase { return Theme.negative }
        if case .upToDate = updates.phase { return Theme.accent }
        return Theme.textSecondary
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        settingsCard(title: "清理行为") {
            VStack(spacing: 0) {
                toggleRow("清理时移到废纸篓",
                          "最安全的方式，文件可在废纸篓中恢复。关闭后将永久删除。",
                          isOn: $settings.moveToTrash)
                DividerLine().padding(.vertical, 12)
                toggleRow("清理前再次确认",
                          "在执行清理前显示确认弹窗，并列出将删除的内容大小。",
                          isOn: $settings.confirmBeforeClean)
                if !settings.moveToTrash {
                    DividerLine().padding(.vertical, 12)
                    warningRow(text: "永久删除模式已开启：清理后的文件不会进入废纸篓。")
                }
            }
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String,
                           isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L(title))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L(subtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .controlSize(.small)
        }
    }

    // MARK: - Exclusions

    private var exclusionSection: some View {
        settingsCard(title: "排除列表") {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("排除的文件或文件夹不会被智能扫描清理，也不会出现在结果中。"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)

                if settings.excludedPaths.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                        Text(L("暂无排除项"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                            .fill(Theme.field)
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(settings.excludedPaths.enumerated()), id: \.element) { index, path in
                            if index > 0 { DividerLine() }
                            exclusionRow(path)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        addExclusion()
                    } label: {
                        Label("添加文件夹…", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))

                    Button {
                        settings.addExclusion(HomePaths.url("Library/Caches").path)
                    } label: {
                        Label("添加示例：用户缓存", systemImage: "shippingbox")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .font(.system(size: 11.5))

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
    }

    private func exclusionRow(_ path: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
            Text(displayPath(path))
                .font(Theme.monoFont(10.5))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button {
                settings.removeExclusion(path)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
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
        panel.title = L("选择要排除的文件或文件夹")
        panel.prompt = L("排除")
        panel.message = L("这些内容将不会被 TidyMac 扫描或清理。")
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                settings.addExclusion(url.path)
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        settingsCard(title: "权限与安全") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: FullDiskAccess.hasAccess() ? "checkmark.shield" : "exclamationmark.shield")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(FullDiskAccess.hasAccess() ? Theme.accent : Theme.caution)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(FullDiskAccess.hasAccess() ? "完全磁盘访问权限已启用" : "建议开启完全磁盘访问权限"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(FullDiskAccess.hasAccess()
                             ? "TidyMac 可以完整扫描缓存、邮件附件与备份。"
                             : "未开启时部分目录无法读取，扫描结果可能不完整。")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button("打开系统设置") { FullDiskAccess.openPrivacySettings() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("列表中找不到 TidyMac？"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    HStack(alignment: .top, spacing: 8) {
                        Text(L("点击列表下方的 +，选择 TidyMac.app；或点击「在 Finder 中显示」，把应用拖入列表。开启开关后请重新启动 TidyMac。"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("在 Finder 中显示") { AppPermissionActions.revealApplicationInFinder() }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                }
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                        .fill(Theme.field)
                )

                DividerLine()

                VStack(alignment: .leading, spacing: 5) {
                    Text(L("安全保护始终开启"))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text(L("系统目录、钥匙串、照片图库、邮件数据库、iCloud 文档等路径受到硬性保护，任何清理操作都会先通过安全策略校验。"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DividerLine()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("在卸载器中显示系统应用"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(L("仅用于查看系统组件占用；受 SIP 保护的系统应用无法卸载。"))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.showSystemApps)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Theme.accent)
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        settingsCard(title: "使用统计") {
            HStack(alignment: .top, spacing: 0) {
                statistic("累计释放", Format.bytes(settings.totalFreedBytes))
                Rectangle().fill(Theme.stroke).frame(width: 1, height: 34)
                    .padding(.horizontal, 26)
                statistic("清理次数", L("\(settings.cleanCount) 次"))
                Rectangle().fill(Theme.stroke).frame(width: 1, height: 34)
                    .padding(.horizontal, 26)
                statistic("上次清理", Format.date(settings.lastCleanDate))
                Spacer(minLength: 0)
            }
            HStack {
                Text(L("统计数据仅保存在本机。"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button("重置统计") { showResetAlert = true }
                    .buttonStyle(GhostButtonStyle())
                    .font(.system(size: 11.5))
            }
            .padding(.top, 2)
        }
    }

    private func statistic(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L(title))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Text(L(value))
                .font(Theme.monoFont(14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minWidth: 120, alignment: .leading)
    }

    // MARK: - About

    private var aboutSection: some View {
        HStack(spacing: 13) {
            AppBrandIcon(size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("TidyMac")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("轻净如羽，焕然一新  ·  v%@  ·  macOS 14+", updates.currentVersion))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text("Made for macOS")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
        .qyPanel(padding: 16)
    }

    // MARK: - Cards

    private func settingsCard<Content: View>(title: String,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(title))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
        .qyPanel(padding: 18)
    }

    private func warningRow(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.caution)
            Text(L(text))
                .font(.system(size: 11))
                .foregroundStyle(Theme.caution)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.cardElevated)
        )
    }
}
