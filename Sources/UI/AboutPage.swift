import AppKit
import SwiftUI

struct AboutPage: View {
    @EnvironmentObject private var app: AppState
    @State private var info = AboutInfo.empty
    @State private var publicIP: String?
    @State private var isFetchingPublicIP = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(title: "关于本机", subtitle: "硬件、系统与网络") {
                    Button(L("刷新")) { reload() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        card(L("硬件"), rows: hardwareRows)
                        if info.battery.isPresent {
                            batteryCard
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    VStack(spacing: 16) {
                        card(L("系统"), rows: systemRows)
                        card(L("网络"), rows: networkRows)
                    }
                    .frame(width: 392)
                }

                Text(L("硬件、系统与局域网信息均在本机读取；公网 IP 通过 Cloudflare / ipify 查询。"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 28)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .onAppear(perform: reload)
    }

    @MainActor
    private func reload() {
        info = AboutInfo.gather(isDemo: app.isDemo)
        if app.isDemo {
            publicIP = "203.0.113.42"
            isFetchingPublicIP = false
            return
        }
        guard !isFetchingPublicIP else { return }
        isFetchingPublicIP = true
        Task {
            let address = await PublicIPService.fetch()
            publicIP = address
            isFetchingPublicIP = false
        }
    }

    // MARK: - Cards

    private func card(_ title: String, rows: [AboutRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 6)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { DividerLine() }
                HStack(alignment: .center, spacing: 16) {
                    Text(row.label)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 12)
                    HStack(spacing: 6) {
                        Text(row.value)
                            .font(row.mono ? Theme.monoFont(11.5, weight: .medium)
                                           : .system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                        if let copyText = row.copyText, !copyText.isEmpty {
                            AboutCopyButton(text: copyText)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qyPanel(padding: 16)
    }

    // MARK: - Rows

    private var hardwareRows: [AboutRow] {
        [
            AboutRow(L("芯片"), info.chip),
            AboutRow(L("CPU 核心"), coresText),
            AboutRow(L("内存"), Format.memory(info.memoryBytes)),
            AboutRow(L("存储"), storageText),
            AboutRow(L("宗卷"), info.disk.volumeName),
            AboutRow(L("显示器"), info.displayName),
            AboutRow(L("分辨率"), resolutionText, mono: true),
            AboutRow(L("机型标识符"), info.modelIdentifier, mono: true)
        ]
    }

    private var systemRows: [AboutRow] {
        [
            AboutRow(L("系统版本"), "macOS \(info.osVersion) (\(info.osBuild))"),
            AboutRow(L("架构"), info.architecture, mono: true),
            AboutRow(L("运行时间"), uptimeText)
        ]
    }

    private var networkRows: [AboutRow] {
        [
            AboutRow(L("主机名"), info.hostName, mono: true),
            AboutRow(L("接口"), info.primaryInterface, mono: true),
            AboutRow(L("本机 IP"), info.ipv4, mono: true, copyText: info.ipv4),
            AboutRow(L("公网 IP"), publicIPText, mono: true, copyText: publicIP),
            AboutRow(L("MAC 地址"), info.macAddress.uppercased(), mono: true, copyText: info.macAddress.uppercased())
        ] + proxyRows
    }

    private var proxyRows: [AboutRow] {
        guard info.proxy.isEnabled else { return [] }
        var rows: [AboutRow] = []
        if !info.proxy.summary.isEmpty {
            rows.append(AboutRow(L("代理"), info.proxy.summary))
        }
        if let copyValue = info.proxy.copyValue {
            rows.append(AboutRow(L("代理地址"), copyValue, mono: true, copyText: copyValue))
        }
        if let pacURL = info.proxy.pacURL {
            rows.append(AboutRow(L("PAC 地址"), pacURL, mono: true, copyText: pacURL))
        }
        return rows
    }

    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("电池"))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 10)
            VStack(spacing: 14) {
                ForEach(Array(batteryStatRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { index, stat in
                            if index > 0 {
                                Rectangle()
                                    .fill(Theme.stroke)
                                    .frame(width: 1, height: 28)
                                    .padding(.horizontal, 16)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stat.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textTertiary)
                                Text(stat.value)
                                    .font(stat.mono ? Theme.monoFont(13, weight: .medium)
                                                    : .system(size: 12.5, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .qyPanel(padding: 16)
    }

    private var batteryStatRows: [[(label: String, value: String, mono: Bool)]] {
        let stats = batteryStats
        return stride(from: 0, to: stats.count, by: 3).map { start in
            Array(stats[start..<min(start + 3, stats.count)])
        }
    }

    private var batteryStats: [(label: String, value: String, mono: Bool)] {
        let battery = info.battery
        var stats: [(String, String, Bool)] = [
            (L("电量"), "\(battery.chargePercent)%", true),
            (L("状态"), batteryStateText, false)
        ]
        if let minutes = batteryTimeMinutes {
            let label = battery.isCharging ? L("充电剩余时间") : L("电池剩余时间")
            stats.append((label, batteryTimeText(minutes), true))
        }
        if let cycles = battery.cycleCount {
            stats.append((L("循环次数"), L("%@ 次", "\(cycles)"), true))
        }
        if let health = battery.healthPercent {
            stats.append((L("电池健康"), "\(health)%", true))
        }
        if let temperature = battery.temperatureCelsius {
            stats.append((L("温度"), String(format: "%.1f°C", temperature), true))
        }
        return stats
    }

    private var batteryStateText: String {
        let battery = info.battery
        if battery.isCharging { return L("充电中") }
        if battery.isCharged { return L("已充满") }
        if battery.isPluggedIn { return L("已接通电源") }
        return L("使用电池")
    }

    private var batteryTimeMinutes: Int? {
        let battery = info.battery
        if battery.isCharging { return battery.minutesToFull }
        if !battery.isPluggedIn { return battery.minutesToEmpty }
        return nil
    }

    private func batteryTimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 {
            return L("%@ 小时 %@ 分钟", "\(hours)", "\(remainder)")
        }
        return L("%@ 分钟", "\(max(1, remainder))")
    }

    private var publicIPText: String {
        if let publicIP { return publicIP }
        return isFetchingPublicIP ? L("查询中…") : "—"
    }

    private var coresText: String {
        if info.performanceCores > 0 || info.efficiencyCores > 0 {
            return L("%@ 核（%@ 性能 + %@ 能效）",
                     "\(info.totalCores)",
                     "\(info.performanceCores)",
                     "\(info.efficiencyCores)")
        }
        return L("%@ 核", "\(info.totalCores)")
    }

    private var storageText: String {
        L("%@ 可用 · 共 %@",
          Format.bytes(info.disk.freeBytes),
          Format.bytes(info.disk.totalBytes))
    }

    private var resolutionText: String {
        if info.screenCount > 1 {
            return info.displayResolution + " · " + L("%@ 个显示器", "\(info.screenCount)")
        }
        return info.displayResolution
    }

    private var uptimeText: String {
        let total = max(0, Int(info.uptimeSeconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 {
            return L("%@ 天 %@ 小时", "\(days)", "\(hours)")
        }
        if hours > 0 {
            return L("%@ 小时 %@ 分钟", "\(hours)", "\(minutes)")
        }
        return L("%@ 分钟", "\(max(1, minutes))")
    }
}

private struct AboutRow {
    let label: String
    let value: String
    var mono = false
    var copyText: String?

    init(_ label: String, _ value: String, mono: Bool = false, copyText: String? = nil) {
        self.label = label
        self.value = value
        self.mono = mono
        self.copyText = copyText
    }
}

private struct AboutCopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(copied ? Theme.accent : Theme.textTertiary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L("复制"))
        .animation(.easeOut(duration: 0.12), value: copied)
    }
}
