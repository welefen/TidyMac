import SwiftUI
import AppKit
import QuartzCore

struct SystemLoadPage: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var monitor = SystemLoadMonitor.shared
    @State private var sort: LoadSort = .cpu
    @State private var expanded: Set<String> = []
    @State private var hoveredAppID: String?
    @State private var hoveredKillID: String?
    @State private var displayedApps: [AppUsage] = []
    @State private var isAppsListHovered = false

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
                PageHeader(title: "系统负载", subtitle: "查看整机与各 App 的 CPU、GPU、内存占用")

                overallCard
                appsCard

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text(L("仅统计当前用户可读进程；CPU 为整机占比，系统守护进程可能未显示。"))
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
            .padding(.top, 28)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            monitor.start(isDemo: app.isDemo, includeApps: false)
            monitor.setAppSamplingEnabled(true)
        }
        .onDisappear { monitor.setAppSamplingEnabled(false) }
        .onChange(of: monitor.snapshot) { _ in
            updateDisplayedApps()
        }
        .onChange(of: sort) { _ in
            displayedApps = sortedApps(monitor.snapshot?.appUsages ?? [])
        }
    }

    // MARK: - Overall

    private var overallCard: some View {
        HStack(alignment: .top, spacing: 0) {
            cpuColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 24)

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1, height: 134)
                .padding(.trailing, 24)

            memoryColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 24)

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1, height: 134)
                .padding(.trailing, 24)

            gpuColumn
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
                FadingNumber(
                    text: monitor.snapshot.map { summaryPercent($0.cpuFraction) } ?? "—",
                    font: Theme.monoFont(40, weight: .medium),
                    color: Theme.textPrimary
                )
                Text(L("%@ 核", "\(monitor.snapshot?.coreCount ?? ProcessInfo.processInfo.activeProcessorCount)"))
                    .font(Theme.monoFont(11))
                    .foregroundStyle(Theme.textTertiary)
            }

            TrendLayerView(values: cpuHistory, color: Theme.accent, minimumSpan: 0.06)
                .frame(height: 32)
                .padding(.top, 2)

            HStack(spacing: 8) {
                Text(L("所有进程合计"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 8)
                Text(trendWindowLabel(monitor.cpuHistory.count))
                    .font(Theme.monoFont(9.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var memoryColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("内存"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                FadingNumber(
                    text: summaryPercent(memoryFraction),
                    font: Theme.monoFont(40, weight: .medium),
                    color: Theme.textPrimary
                )
                if let snapshot = monitor.snapshot {
                    Text("\(Format.bytes(snapshot.memoryUsedBytes)) / \(Format.bytes(snapshot.memoryTotalBytes))")
                        .font(Theme.monoFont(11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            TrendLayerView(values: memoryHistory, color: Theme.accent.opacity(0.78), minimumSpan: 0.025)
                .frame(height: 32)
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
                Spacer(minLength: 8)
                Text(trendWindowLabel(monitor.memoryHistory.count))
                    .font(Theme.monoFont(9.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var cpuHistory: [Double] {
        trend(monitor.cpuHistory, current: monitor.snapshot?.cpuFraction ?? 0)
    }

    private var memoryHistory: [Double] {
        trend(monitor.memoryHistory, current: memoryFraction)
    }

    private var gpuHistory: [Double] {
        trend(monitor.gpuHistory, current: monitor.snapshot?.gpu?.utilizationFraction ?? 0)
    }

    private func trend(_ history: [Double], current: Double) -> [Double] {
        history.count > 1 ? history : [current, current]
    }

    /// Until the two-minute window fills, name the window we actually have.
    private func trendWindowLabel(_ count: Int) -> String {
        guard count < SystemLoadMonitor.historyCapacity else { return L("最近 1 分钟") }
        let seconds = max(Int(Double(count) * SystemLoadMonitor.refreshInterval), 1)
        return L("最近 %d 秒", seconds)
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

    private var gpuColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("GPU")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 8)
                if let gpu = monitor.snapshot?.gpu {
                    Text(gpu.model)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    if gpu.coreCount > 0 {
                        Text(L("%@ 核", "\(gpu.coreCount)"))
                            .font(Theme.monoFont(9.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            if let gpu = monitor.snapshot?.gpu {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    FadingNumber(
                        text: summaryPercent(gpu.utilizationFraction),
                        font: Theme.monoFont(40, weight: .medium),
                        color: Theme.textPrimary
                    )
                    Text(L("利用率"))
                        .font(Theme.monoFont(11))
                        .foregroundStyle(Theme.textTertiary)
                }

                TrendLayerView(values: gpuHistory, color: Theme.accent, minimumSpan: 0.08)
                    .frame(height: 32)
                    .padding(.top, 2)

                HStack(spacing: 8) {
                    Text(L("所有 GPU 任务"))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    Text(trendWindowLabel(monitor.gpuHistory.count))
                        .font(Theme.monoFont(9.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            } else {
                Text("—")
                    .font(Theme.monoFont(40, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Text(L("无法读取此设备的 GPU 统计"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Apps

    private func sortedApps(_ apps: [AppUsage]) -> [AppUsage] {
        switch sort {
        case .cpu: return apps.sorted { $0.cpuFraction > $1.cpuFraction }
        case .memory: return apps.sorted { $0.memoryBytes > $1.memoryBytes }
        }
    }

    /// Keeps row order stable while the pointer is over the list so buttons don't move
    /// away mid-click; values still refresh in place, and removed apps drop out.
    private func updateDisplayedApps() {
        guard let apps = monitor.snapshot?.appUsages else { return }
        guard isAppsListHovered, !displayedApps.isEmpty else {
            displayedApps = sortedApps(apps)
            return
        }
        let byID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existingOrder = displayedApps.map(\.id)
        var next = existingOrder.compactMap { byID[$0] }
        let known = Set(existingOrder)
        let additions = apps.filter { !known.contains($0.id) }
        next.append(contentsOf: sortedApps(additions))
        displayedApps = next
    }

    private var appsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(L("各 App 占用"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("%@ 个 App", "\(displayedApps.count)"))
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

            if displayedApps.isEmpty {
                Text(monitor.snapshot == nil ? L("正在读取…") : L("暂无可读取的 App 进程"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    ForEach(displayedApps) { usage in
                        appRow(usage)
                    }

                }
            }
        }
        .qyPanel(padding: 0)
        .onHover { inside in
            isAppsListHovered = inside
            if !inside { updateDisplayedApps() }
        }
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

    private func summaryPercent(_ fraction: Double) -> String {
        String(format: "%.0f%%", (max(0, fraction) * 100).rounded())
    }

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

/// A quiet two-minute sparkline: a hairline trend and a barely-there area wash
/// on a neutral strip. No axes, no glow — the big figure next to it carries the value.
/// Numbers roll between values with SwiftUI's numeric content transition.
private struct FadingNumber: View {
    let text: String
    let font: Font
    let color: Color

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(.easeOut(duration: 0.28), value: text)
    }
}

private struct TrendLayerView: NSViewRepresentable {
    let values: [Double]
    let color: Color
    var minimumSpan: Double = 0.06
    var interval: TimeInterval = 1

    func makeNSView(context: Context) -> TrendHostView {
        TrendHostView()
    }

    func updateNSView(_ view: TrendHostView, context: Context) {
        view.apply(values: values, color: color, minimumSpan: minimumSpan, interval: interval)
    }
}

/// AppKit-backed chart so the one-second right-to-left push runs as a Core
/// Animation transform on a rasterized curve. A SwiftUI offset animation would
/// invalidate the whole System Load page every frame and burn CPU.
final class TrendHostView: NSView {
    private let contentLayer = CALayer()
    private let outgoingLayer = CALayer()
    private var isTransitioning = false
    private var currentValues: [Double] = []
    private var currentColor: Color = Theme.accent
    private var currentSpan: Double = 0.06
    private var currentInterval: TimeInterval = 1
    private var renderedSize: CGSize = .zero
    private var renderedColor: Color = .clear
    private var renderedSpan: Double = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        contentLayer.anchorPoint = .zero
        contentLayer.position = .zero

        outgoingLayer.anchorPoint = .zero
        outgoingLayer.position = .zero
        outgoingLayer.isHidden = true

        layer?.addSublayer(outgoingLayer)
        layer?.addSublayer(contentLayer)
    }

    required init?(coder: NSCoder) { nil }

    func apply(values: [Double], color: Color, minimumSpan: Double, interval: TimeInterval) {
        let valuesChanged = values != currentValues
        let styleChanged = color != renderedColor || minimumSpan != renderedSpan
        currentValues = values
        currentColor = color
        currentSpan = minimumSpan
        currentInterval = interval

        if bounds.size != renderedSize {
            render(animate: false)
        } else if valuesChanged {
            render(animate: true)
        } else if styleChanged {
            render(animate: false)
        }
    }

    override func layout() {
        super.layout()
        if bounds.size != renderedSize {
            render(animate: false)
        }
    }

    private func render(animate: Bool) {
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return }
        renderedSize = size

        let samples = normalized(currentValues)
        let content = TrendCanvas(samples: samples, color: currentColor)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        renderer.scale = scale
        guard let image = renderer.cgImage else { return }

        if isTransitioning {
            contentLayer.removeAnimation(forKey: "push")
            outgoingLayer.removeAnimation(forKey: "push")
            contentLayer.position = .zero
            outgoingLayer.isHidden = true
            isTransitioning = false
        }

        let oldContents = contentLayer.contents
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.contents = image
        contentLayer.contentsScale = scale
        contentLayer.frame = CGRect(origin: .zero, size: size)
        contentLayer.position = .zero
        renderedColor = currentColor
        renderedSpan = currentSpan
        CATransaction.commit()

        contentLayer.removeAnimation(forKey: "push")
        guard animate, let oldContents else { return }

        let capacity = SystemLoadMonitor.historyCapacity
        let step = size.width / CGFloat(max(capacity - 1, 1))

        outgoingLayer.contents = oldContents
        outgoingLayer.contentsScale = scale
        outgoingLayer.frame = CGRect(origin: .zero, size: size)
        outgoingLayer.opacity = 1
        outgoingLayer.isHidden = false

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.position = CGPoint(x: step, y: 0)
        outgoingLayer.position = .zero
        CATransaction.commit()

        let push = CABasicAnimation(keyPath: "position.x")
        push.fromValue = step
        push.toValue = 0
        push.duration = currentInterval * 0.9
        push.timingFunction = CAMediaTimingFunction(name: .linear)

        isTransitioning = true
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.contentLayer.position = .zero
            self.outgoingLayer.isHidden = true
            self.outgoingLayer.removeAnimation(forKey: "push")
            self.isTransitioning = false
        }
        contentLayer.add(push, forKey: "push")
        CATransaction.commit()
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let samples = values.isEmpty ? [0] : values
        let lower = (samples.min() ?? 0) - 0.012
        let upper = (samples.max() ?? 1) + 0.012
        let span = max(upper - lower, currentSpan)
        return samples.map { min(max(($0 - lower) / span, 0), 1) }
    }
}

private struct TrendCanvas: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        Canvas { canvas, size in
            let rect = CGRect(origin: .zero, size: size)
            canvas.fill(Path(rect), with: .color(Theme.card))
            canvas.fill(
                Path(roundedRect: rect, cornerRadius: 5),
                with: .color(Theme.subtleFill)
            )

            let capacity = SystemLoadMonitor.historyCapacity
            let step = size.width / CGFloat(max(capacity - 1, 1))
            let points = TrendLayout.points(samples: samples, step: step, size: size)
            if points.count > 1 {
                canvas.fill(
                    TrendLayout.areaPath(points, in: size),
                    with: .color(color.opacity(0.08))
                )
                canvas.stroke(
                    TrendLayout.smoothPath(points),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                )
            }

            var hairline = Path()
            hairline.move(to: CGPoint(x: 0, y: size.height - 0.5))
            hairline.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
            canvas.stroke(hairline, with: .color(Theme.stroke), lineWidth: 1)
        }
    }
}

/// Newest samples sit at the right edge; older samples march left one slot
/// per second. Each refresh draws the new curve shifted right by one slot and
/// slides it left over the previous frame, so the chart advances without any
/// backward jump.
private enum TrendLayout {
    static func points(samples: [Double], step: CGFloat, size: CGSize) -> [CGPoint] {
        guard !samples.isEmpty, step > 0, size.height > 0 else { return [] }
        let count = samples.count
        return samples.enumerated().map { index, value in
            let age = CGFloat(count - 1 - index)
            return CGPoint(
                x: size.width - age * step,
                y: size.height * (1 - CGFloat(value))
            )
        }
    }

    static func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])

        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        return path
    }

    static func areaPath(_ points: [CGPoint], in size: CGSize) -> Path {
        guard let first = points.first, let last = points.last, points.count > 1 else {
            return Path()
        }
        var path = smoothPath(points)
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}
