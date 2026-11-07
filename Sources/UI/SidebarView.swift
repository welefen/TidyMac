import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var updates: UpdateManager

    private var appVersion: String { updates.currentVersion }
    @State private var hoveredPage: AppPage?
    @State private var hoveringUpdateBadge = false

    private var mainPages: [AppPage] { [.overview, .smartScan] }
    private var toolPages: [AppPage] { [.uninstaller, .largeFiles, .spaceLens] }

    var body: some View {
        ZStack(alignment: .trailing) {
            Theme.sidebar
            LinearGradient(
                colors: [Theme.mint.opacity(0.045), .clear, Theme.blue.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                brand
                    .padding(.top, 52)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(mainPages) { page in
                        navRow(page)
                    }
                }
                .padding(.top, 28)

                sectionLabel("工具")
                    .padding(.top, 24)
                    .padding(.bottom, 7)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(toolPages) { page in
                        navRow(page)
                    }
                }

                Spacer(minLength: 16)

                storageCard
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                settingsRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 10)
        }
        .ignoresSafeArea()
    }

    // MARK: Brand

    private var brand: some View {
        HStack(spacing: 8) {
            AppBrandIcon(size: 42)
                .shadow(color: Theme.mint.opacity(0.20), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .center, spacing: 6) {
                    Text("TidyMac")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .fixedSize()
                    versionBadge
                }
                Text("SMART CLEAN")
                    .font(.system(size: 7.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer(minLength: 0)
        }
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
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func downloadingBadge(version: String) -> some View {
        ZStack {
            Circle()
                .fill(Theme.mint)
            ZStack {
                Circle()
                    .strokeBorder(Theme.textOnMint.opacity(0.88), lineWidth: 1.1)
                    .frame(width: 12.5, height: 12.5)
                Image(systemName: "arrow.down")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(Theme.textOnMint)
            }
            .symbolEffect(.pulse, options: .repeating)
        }
        .frame(width: 22, height: 22)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8))
        .shadow(color: Theme.mint.opacity(0.24), radius: 4, x: 0, y: 2)
        .help(L("正在下载 v%@…", version))
        .accessibilityLabel(L("正在下载 v%@…", version))
    }

    /// A mint update button: a small arrow circle by default that expands into a
    /// labelled pill on hover, matching the app's primary button colour.
    private func updateBadge(version: String) -> some View {
        Button {
            updates.installDownloadedUpdate()
        } label: {
            HStack(spacing: 0) {
                if hoveringUpdateBadge {
                    Text(L("完成更新"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textOnMint)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)
                } else {
                    updateBadgeGlyph()
                }
            }
            .frame(height: 22)
            .frame(minWidth: 22)
            .background(Capsule(style: .continuous).fill(Theme.mint))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
            )
            .shadow(color: Theme.mint.opacity(hoveringUpdateBadge ? 0.34 : 0.24),
                    radius: hoveringUpdateBadge ? 6 : 4, x: 0, y: 2)
            .contentShape(Capsule(style: .continuous))
            .animation(.spring(response: 0.26, dampingFraction: 0.82), value: hoveringUpdateBadge)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveringUpdateBadge = hovering
        }
        .help(L("有新版本 v%@，点击安装", version))
        .accessibilityLabel(L("有新版本 v%@，点击安装", version))
    }

    private func updateBadgeGlyph() -> some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.textOnMint.opacity(0.88), lineWidth: 1.1)
                .frame(width: 12.5, height: 12.5)
            Image(systemName: "arrow.up")
                .font(.system(size: 7, weight: .heavy))
                .foregroundStyle(Theme.textOnMint)
        }
        .frame(width: 22, height: 22)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(L(text))
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Theme.textTertiary.opacity(0.85))
            .padding(.leading, 11)
    }

    // MARK: Navigation

    private func navRow(_ page: AppPage) -> some View {
        let selected = app.page == page
        let hovered = hoveredPage == page
        return Button {
            app.navigate(to: page)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: page.symbol)
                    .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
                    .frame(width: 22)
                    .foregroundStyle(selected ? Theme.mint : Theme.textSecondary)
                Text(L(page.title))
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer(minLength: 4)
                if page == .smartScan, app.phase == .results,
                   let found = app.scanResult?.totalBytesFound, found > 0 {
                    TagBadge(text: Format.bytes(found), tone: .mint)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Theme.cardElevated
                          : (hovered ? Theme.card.opacity(0.55) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Theme.strokeStrong : Color.clear, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                if selected {
                    Capsule()
                        .fill(Theme.gradient(.mint))
                        .frame(width: 3, height: 17)
                        .offset(x: -1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredPage = isHovering ? page : (hoveredPage == page ? nil : hoveredPage)
        }
    }

    // MARK: Bottom cards

    private var storageCard: some View {
        Button {
            app.navigate(to: .overview)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                    Text(L("存储空间"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(L("\(Format.bytes(app.disk.freeBytes)) 可用"))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.mint)
                }
                StorageBar(usedFraction: app.disk.usedFraction,
                           tone: app.disk.usedFraction > 0.88 ? .orange : .mint,
                           height: 5)
                HStack {
                    Text(L("已用 \(Format.bytes(app.disk.usedBytes))"))
                    Spacer()
                    Text(L("共 \(Format.bytes(app.disk.totalBytes))"))
                }
                .font(.system(size: 9))
                .foregroundStyle(Theme.textTertiary)
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.card.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var settingsRow: some View {
        Button {
            app.navigate(to: .settings)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 22)
                    .foregroundStyle(app.page == .settings ? Theme.mint : Theme.textSecondary)
                Text(L("设置"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(app.page == .settings ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(app.page == .settings ? Theme.cardElevated : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
