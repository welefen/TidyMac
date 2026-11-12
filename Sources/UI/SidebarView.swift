import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var updates: UpdateManager

    private var appVersion: String { updates.currentVersion }
    @State private var hoveredPage: AppPage?
    @State private var hoveringUpdateBadge = false

    private var mainPages: [AppPage] { [.overview, .smartScan] }
    private var toolPages: [AppPage] { [.uninstaller, .largeFiles, .spaceLens, .systemLoad, .about] }

    var body: some View {
        ZStack(alignment: .trailing) {
            Theme.sidebar
            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                brand
                    .padding(.top, 44)
                    .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(mainPages) { page in
                        navRow(page)
                    }
                }
                .padding(.top, 28)

                sectionLabel("工具")
                    .padding(.top, 26)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(toolPages) { page in
                        navRow(page)
                    }
                }

                Spacer(minLength: 16)

                storageCard
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)

                settingsRow
                    .padding(.horizontal, 10)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 8)
        }
        .ignoresSafeArea()
    }

    // MARK: Brand

    private var brand: some View {
        HStack(spacing: 10) {
            AppBrandIcon(size: 32)
            Text("TidyMac")
                .font(Theme.wordmarkFont)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            versionBadge
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var versionBadge: some View {
        switch updates.phase {
        case .available(let version), .downloading(let version):
            downloadingBadge(version: version)
        case .ready(let version):
            updateBadge(version: version)
        default:
            Text("v\(appVersion)")
                .font(Theme.monoFont(10))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func downloadingBadge(version: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .semibold))
            Text(L("下载中"))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.card)
        )
        .help(L("正在下载 v%@…", version))
        .accessibilityLabel(L("正在下载 v%@…", version))
    }

    /// Quiet update cue: a 18pt accent square with an up arrow that widens to
    /// "Update" on hover. One easing, no glow.
    private func updateBadge(version: String) -> some View {
        Button {
            updates.installDownloadedUpdate()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .semibold))
                if hoveringUpdateBadge {
                    Text(L("更新"))
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(Theme.textOnAccent)
            .padding(.horizontal, hoveringUpdateBadge ? 7 : 5)
            .frame(height: 18)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.accent)
            )
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: hoveringUpdateBadge)
        }
        .buttonStyle(.plain)
        .onHover { hoveringUpdateBadge = $0 }
        .help(L("有新版本 v%@，点击安装", version))
        .accessibilityLabel(L("有新版本 v%@，点击安装", version))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(L(text))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textTertiary)
            .padding(.leading, 10)
    }

    // MARK: Navigation

    private func navRow(_ page: AppPage) -> some View {
        let selected = app.page == page
        let hovered = hoveredPage == page
        return Button {
            app.navigate(to: page)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: page.symbol)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 20)
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                Text(L(page.title))
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer(minLength: 4)
                if page == .smartScan, app.phase == .results,
                   let found = app.scanResult?.totalBytesFound, found > 0 {
                    Text(Format.bytes(found))
                        .font(Theme.monoFont(10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(selected ? Theme.cardElevated : (hovered ? Theme.subtleFill : Color.clear))
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: selected)
            .animation(.easeOut(duration: 0.15), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredPage = isHovering ? page : (hoveredPage == page ? nil : hoveredPage)
        }
    }

    // MARK: Bottom

    private var storageCard: some View {
        Button {
            app.navigate(to: .overview)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Theme.textTertiary)
                    Text(L("存储空间"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(L("\(Format.bytes(app.disk.freeBytes)) 可用"))
                        .font(Theme.monoFont(10))
                        .foregroundStyle(Theme.textSecondary)
                }
                CapacityRuler(fraction: app.disk.usedFraction, height: 5)
                HStack {
                    Text(L("已用 \(Format.bytes(app.disk.usedBytes))"))
                    Spacer()
                    Text(L("共 \(Format.bytes(app.disk.totalBytes))"))
                }
                .font(Theme.monoFont(9.5))
                .foregroundStyle(Theme.textTertiary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(L("查看总览"))
    }

    private var settingsRow: some View {
        Button {
            app.navigate(to: .settings)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 20)
                    .foregroundStyle(app.page == .settings ? Theme.textPrimary : Theme.textSecondary)
                Text(L("设置"))
                    .font(.system(size: 13, weight: app.page == .settings ? .medium : .regular))
                    .foregroundStyle(app.page == .settings ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(app.page == .settings ? Theme.cardElevated : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
