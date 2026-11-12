import SwiftUI
import AppKit

struct SystemLoadPage: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var monitor = SystemLoadMonitor()
    @State private var sort: LoadSort = .cpu
    @State private var expanded: Set<String> = []
    @State private var hoveredAppID: String?
    @State private var hoveredKillID: String?

    private enum LoadSort: String, CaseIterable {
        case cpu
        case memory

        var title: String {
            switch self {
            case .cpu: return L("按 CPU")
            case .memory: return L("按内存")
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(title: "系统负载", subtitle: "查看整机与各 App 的 CPU、内存占用") {
                    Text(L("每 2 秒刷新"))
                        .font(Theme.monoFont(10))
                        .foregroundStyle(Theme.textTertiary)
                }

                overallCard
                appsCard

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text(L("仅统计当前用户可读进程；系统守护进程可能未显示。"))
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)

                if let snapshot = monitor.snapshot {
                    Text(L("上次采样 %@", timeString(snapshot.sampledAt)))
                        .font(Theme.monoFont(10))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
            .padding(.bottom, 40)
            .frame(maxWidth: 1100)
        }
        .onAppear { monitor.start(isDemo: app.isDemo) }
        .onDisappear { monitor.stop() }
    }

    // MARK: - Overall

    private var overallCard: some View {
        HStack(alignment: .top, spacing: 0) {
            cpuColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 28)

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1, height: 120)
                .padding(.trailing, 28)

            memoryColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .qyPanel(padding: 22)
    }

    private var cpuColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CPU")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(monitor.snapshot.map { percent($0.cpuFraction) } ?? "—")
                    .font(Theme.monoFont(40, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("%@ 核", "\(monitor.snapshot?.coreCount ?? ProcessInfo.processInfo.activeProcessorCount)"))
                    .font(Theme.monoFont(11))
                    .foregroundStyle(Theme.textTertiary)
            }

            CapacityRuler(fraction: monitor.snapshot?.cpuFraction ?? 0, height: 6)
                .padding(.top, 2)

            Text(L("所有进程合计"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var memoryColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("内存"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                let parts = monitor.snapshot.map { Format.bytesParts($0.memoryUsedBytes) }
                Text(parts?.number ?? "—")
                    .font(Theme.monoFont(40, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                if let unit = parts?.unit, !unit.isEmpty {
                    Text(unit)
                        .font(Theme.monoFont(14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                if let snapshot = monitor.snapshot {
                    Text("/ " + Format.bytes(snapshot.memoryTotalBytes))
                        .font(Theme.monoFont(11))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 4)
                }
            }

            CapacityRuler(fraction: memoryFraction, height: 6)
                .padding(.top, 2)

            HStack(spacing: 10) {
                Text(monitor.snapshot?.memoryPressure.title ?? L("内存压力正常"))
                    .font(.system(size: 11))
                    .foregroundStyle(pressureColor)
                if let snapshot = monitor.snapshot, snapshot.swapUsedBytes > 0 {
                    Text(L("交换 %@", Format.bytes(snapshot.swapUsedBytes)))
                        .font(Theme.monoFont(10.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private var memoryFraction: Double {
        guard let snapshot = monitor.snapshot, snapshot.memoryTotalBytes > 0 else { return 0 }
        return Double(snapshot.memoryUsedBytes) / Double(snapshot.memoryTotalBytes)
    }

    private var pressureColor: Color {
        switch monitor.snapshot?.memoryPressure {
        case .normal, .none: return Theme.textSecondary
        case .warning: return Theme.caution
        case .critical: return Theme.negative
        }
    }

    // MARK: - Apps

    private var sortedApps: [AppUsage] {
        let apps = monitor.snapshot?.appUsages ?? []
        switch sort {
        case .cpu: return apps.sorted { $0.cpuFraction > $1.cpuFraction }
        case .memory: return apps.sorted { $0.memoryBytes > $1.memoryBytes }
        }
    }

    private var appsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(L("各 App 占用"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("%@ 个 App", "\(sortedApps.count)"))
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                ForEach(LoadSort.allCases, id: \.self) { option in
                    FilterPill(title: option.title, isSelected: sort == option) {
                        sort = option
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            DividerLine()

            tableHeader

            if sortedApps.isEmpty {
                Text(monitor.snapshot == nil ? L("正在读取…") : L("暂无可读取的 App 进程"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedApps) { usage in
                        appRow(usage)
                    }
                }
            }
        }
        .qyPanel(padding: 0)
    }

    private var tableHeader: some View {
        HStack(spacing: 10) {
            Text(L("应用"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU")
                .frame(width: 64, alignment: .trailing)
            Text(L("内存"))
                .frame(width: 84, alignment: .trailing)
            Text(L("进程"))
                .frame(width: 64, alignment: .trailing)
            Color.clear.frame(width: 14)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(Theme.textTertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Theme.field.opacity(0.55))
    }

    private func appRow(_ usage: AppUsage) -> some View {
        let isExpanded = expanded.contains(usage.id)
        let expandable = usage.processCount > 1
        let isHovered = hoveredAppID == usage.id
        let killPID = killPID(for: usage)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: AppIconStore.icon(for: usage.bundlePath))
                    .resizable()
                    .frame(width: 22, height: 22)
                let displayName = app.isDemo ? usage.name : AppNameStore.name(for: usage.bundlePath, fallback: usage.name)
                Text(displayName)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if isHovered, let pid = killPID {
                    Button {
                        terminateApp(usage, pid: pid)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        hoveredKillID = inside ? usage.id : nil
                    }
                    .overlay(alignment: .top) {
                        if hoveredKillID == usage.id {
                            Text(L("结束「%@」", displayName))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Theme.textPrimary.opacity(0.92))
                                )
                                .fixedSize()
                                .offset(y: -26)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.12), value: hoveredKillID)
                }
                Spacer(minLength: 8)
                Text(percent(usage.cpuFraction))
                    .font(Theme.monoFont(11.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 64, alignment: .trailing)
                Text(Format.bytes(usage.memoryBytes))
                    .font(Theme.monoFont(11.5))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 84, alignment: .trailing)
                Text("\(usage.processCount)")
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 64, alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Theme.textTertiary.opacity(expandable ? 1 : 0))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(isHovered || isExpanded ? Theme.subtleFill : Color.clear)
            .onTapGesture {
                guard expandable else { return }
                if isExpanded { expanded.remove(usage.id) } else { expanded.insert(usage.id) }
            }
            .onHover { inside in
                if inside {
                    hoveredAppID = usage.id
                } else if hoveredAppID == usage.id {
                    hoveredAppID = nil
                }
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(usage.processes) { proc in
                        HStack(spacing: 10) {
                            Rectangle()
                                .fill(Theme.stroke)
                                .frame(width: 1, height: 14)
                                .padding(.leading, 24)
                            Text(proc.name)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(percent(proc.cpuFraction))
                                .font(Theme.monoFont(10.5))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 64, alignment: .trailing)
                            Text(Format.bytes(proc.memoryBytes))
                                .font(Theme.monoFont(10.5))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textTertiary)
                                .frame(width: 84, alignment: .trailing)
                            Text("PID \(proc.pid)")
                                .font(Theme.monoFont(9.5))
                                .foregroundStyle(Theme.textTertiary.opacity(0.8))
                                .frame(width: 64 + 14, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }
                .background(Theme.field.opacity(0.4))
            }

            DividerLine()
        }
    }

    /// The main process of an app we are allowed to terminate: same user, not TidyMac itself,
    /// and not a system app under /System.
    private func killPID(for usage: AppUsage) -> pid_t? {
        guard !app.isDemo else { return nil }
        guard let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.path == usage.bundlePath
        }) else { return nil }
        guard running.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        guard let path = running.bundleURL?.path, !path.hasPrefix("/System/") else { return nil }
        return running.processIdentifier
    }

    private func terminateApp(_ usage: AppUsage, pid: pid_t) {
        guard let running = NSRunningApplication(processIdentifier: pid) else { return }
        if !running.terminate() {
            running.forceTerminate()
        }
        // Some apps (or processes without an event loop) ignore a graceful quit.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !running.isTerminated {
                running.forceTerminate()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                monitor.refreshNow()
            }
        }
    }

    // MARK: - Formatting

    private func percent(_ fraction: Double) -> String {
        let value = max(0, fraction) * 100
        if value < 0.05 { return "0%" }
        if value < 10 { return String(format: "%.1f%%", value) }
        return String(format: "%.0f%%", value)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

@MainActor
private enum AppNameStore {
    private static var cache: [String: String] = [:]

    static func name(for bundlePath: String, fallback: String) -> String {
        if let cached = cache[bundlePath] { return cached }
        let running = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.path == bundlePath
        }
        let isChinese = Bundle.main.preferredLocalizations.first?.hasPrefix("zh") ?? true
        let info = running?.bundleURL.flatMap { Bundle(url: $0) }
        let localized = isChinese
            ? running?.localizedName
            : (info?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
               ?? info?.object(forInfoDictionaryKey: "CFBundleName") as? String)
        let value = localized ?? fallback
        cache[bundlePath] = value
        return value
    }
}

@MainActor
private enum AppIconStore {
    private static var cache: [String: NSImage] = [:]

    static func icon(for path: String) -> NSImage {
        if let image = cache[path] { return image }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache[path] = image
        return image
    }
}
