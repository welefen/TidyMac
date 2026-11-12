import AppKit
import SwiftUI

struct AboutPage: View {
    @EnvironmentObject private var app: AppState
    @State private var info = AboutInfo.empty
    @State private var publicIP: String?
    @State private var isFetchingPublicIP = false
    @State private var speedSource: SpeedTestSource = .cloudflare
    @State private var speedResult: SpeedTestResult?
    @State private var speedStatus: String?
    @State private var isSpeedTesting = false
    @State private var speedTask: Task<Void, Never>?
    @State private var speedStartedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(title: "关于本机", subtitle: "硬件、系统与网络") {
                    Button(L("刷新")) { reload() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }

                HStack(alignment: .top, spacing: 16) {
                    card(L("硬件"), rows: hardwareRows)
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 16) {
                        card(L("系统"), rows: systemRows)
                        card(L("网络"), rows: networkRows)
                    }
                    .frame(width: 392)
                }

                speedTestCard

                Text(L("硬件、系统与局域网信息均在本机读取；公网 IP 通过 Cloudflare / ipify 查询，测速流量发送给 Cloudflare 或 Apple。"))
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
        .onDisappear {
            speedTask?.cancel()
            speedTask = nil
        }
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

    // MARK: - Speed test

    private var speedTestCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(L("网络测速"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(SpeedTestSource.allCases) { source in
                        FilterPill(title: source.title, isSelected: speedSource == source) {
                            guard !isSpeedTesting else { return }
                            speedSource = source
                            speedResult = nil
                            speedStatus = nil
                        }
                    }
                }
                .disabled(isSpeedTesting)
                if isSpeedTesting {
                    Button(L("取消")) { toggleSpeedTest() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                } else {
                    Button(L("开始测速")) { toggleSpeedTest() }
                        .buttonStyle(PrimaryButtonStyle(compact: true))
                }
            }

            if isSpeedTesting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(speedStatus ?? L("准备中…"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let started = speedStartedAt {
                            Text(L("已用时 %@ 秒", "\(Int(context.date.timeIntervalSince(started)))"))
                                .font(Theme.monoFont(10.5))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            } else if let result = speedResult {
                HStack(spacing: 0) {
                    speedStat(L("延迟"), value: latencyValue(result.latencyMs), unit: "ms")
                    speedDivider
                    speedStat(L("下载"), value: mbpsValue(result.downloadMbps), unit: "Mbps")
                    speedDivider
                    speedStat(L("上传"), value: mbpsValue(result.uploadMbps), unit: "Mbps")
                }
                Text(L("结果仅供参考；测试流量会发送给 Cloudflare 或 Apple。"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Text(speedStatus ?? L("尚未测速。Cloudflare 测试约消耗 14 MB 流量；系统测试约需 25 秒。"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(speedStatus == nil ? Theme.textSecondary : Theme.negative)
            }
        }
        .qyPanel(padding: 16)
    }

    private func speedStat(_ label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.monoFont(24, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(Theme.monoFont(11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var speedDivider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 36)
            .padding(.horizontal, 16)
    }

    private func latencyValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))"
    }

    private func mbpsValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: value >= 100 ? "%.0f" : "%.1f", value)
    }

    private func toggleSpeedTest() {
        if isSpeedTesting {
            speedTask?.cancel()
            speedTask = nil
            isSpeedTesting = false
            speedStartedAt = nil
            speedStatus = nil
            return
        }

        speedResult = nil
        speedStatus = L("正在测速…")
        isSpeedTesting = true
        speedStartedAt = Date()
        let source = speedSource
        speedTask = Task { @MainActor in
            var outcome: Result<SpeedTestResult, Error>?
            do {
                switch source {
                case .cloudflare:
                    speedStatus = L("正在测试延迟、下载与上传…")
                    outcome = .success(try await SpeedTestRunner.cloudflare())
                case .system:
                    speedStatus = L("正在运行系统网络质量测试（约 25 秒）…")
                    outcome = .success(try await SpeedTestRunner.systemNetworkQuality())
                }
            } catch {
                outcome = .failure(error)
            }

            speedStartedAt = nil
            isSpeedTesting = false
            if Task.isCancelled {
                speedStatus = nil
                return
            }
            switch outcome {
            case .success(let result):
                speedResult = result
                speedStatus = nil
            case .failure(let error):
                speedStatus = L("测速失败：%@", error.localizedDescription)
            case .none:
                speedStatus = nil
            }
        }
    }

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
