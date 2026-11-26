import AppKit
import Combine

extension Notification.Name {
    static let tidymacOpenSystemLoad = Notification.Name("tidymac.openSystemLoad")
}

final class MenuBarStatsController {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let monitor = SystemLoadMonitor.shared
    private var cancellable: AnyCancellable?

    private let trendsItem = NSMenuItem()
    private let trendsView = MenuBarTrendsView()

    init() {
        buildMenu()
        createStatusItem()

        cancellable = monitor.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.apply(snapshot)
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.setAccessibilityIdentifier("com.tidymac.clean.statusItemButton")
            button.setAccessibilityTitle("TidyMac")
            button.setAccessibilityLabel("TidyMac CPU")

            let symbol = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: L("系统负载"))
            symbol?.isTemplate = true
            button.image = symbol
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
            button.title = "—"
            button.toolTip = L("CPU 使用率")
        }
        item.menu = menu
        statusItem = item
        apply(monitor.snapshot)
    }

    private func buildMenu() {
        menu.autoenablesItems = false
        trendsView.frame = NSRect(origin: .zero, size: MenuBarTrendsView.panelSize)
        trendsItem.view = trendsView
        trendsItem.isEnabled = true
        menu.addItem(trendsItem)
        menu.addItem(.separator())

        let openLoad = NSMenuItem(title: L("打开系统负载…"),
                                  action: #selector(openSystemLoad),
                                  keyEquivalent: "")
        openLoad.target = self
        menu.addItem(openLoad)

        let openApp = NSMenuItem(title: L("打开 TidyMac"),
                                 action: #selector(openApp),
                                 keyEquivalent: "")
        openApp.target = self
        menu.addItem(openApp)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("退出 TidyMac"),
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func apply(_ snapshot: SystemLoadSnapshot?) {
        guard let snapshot else {
            statusItem.button?.title = "—"
            trendsView.update(snapshot: nil, cpuHistory: [], memoryHistory: [], gpuHistory: [], downloadHistory: [], uploadHistory: [])
            return
        }

        let cpu = Int((snapshot.cpuFraction * 100).rounded())
        statusItem.button?.attributedTitle = cpuTitle(for: cpu)
        statusItem.button?.toolTip = L("CPU %@", "\(cpu)%")
        trendsView.update(
            snapshot: snapshot,
            cpuHistory: monitor.cpuHistory,
            memoryHistory: monitor.memoryHistory,
            gpuHistory: monitor.gpuHistory,
            downloadHistory: monitor.downloadHistory,
            uploadHistory: monitor.uploadHistory
        )
    }

    private func cpuTitle(for cpu: Int) -> NSAttributedString {
        let color: NSColor
        if cpu >= 85 {
            color = .systemRed
        } else if cpu >= 60 {
            color = .systemOrange
        } else {
            color = .labelColor
        }
        return NSAttributedString(string: "\(cpu)%", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: color
        ])
    }


    @objc private func openSystemLoad() {
        NotificationCenter.default.post(name: .tidymacOpenSystemLoad, object: nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }

    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }
}

private final class MenuBarTrendsView: NSView {
    static let panelSize = NSSize(width: 360, height: 236)

    private var snapshot: SystemLoadSnapshot?
    private var cpuHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private var gpuHistory: [Double] = []
    private var downloadHistory: [Double] = []
    private var uploadHistory: [Double] = []

    private let inset: CGFloat = 10
    private let gap: CGFloat = 10
    private let chartHeight: CGFloat = 26

    private let charts: [TrendHostView] = (0..<5).map { _ in
        let chart = TrendHostView()
        chart.drawsBackground = false
        chart.wantsLayer = true
        return chart
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        charts.forEach(addSubview)
        charts[4].showsArea = false
    }

    required init?(coder: NSCoder) { nil }

    func update(snapshot: SystemLoadSnapshot?,
                cpuHistory: [Double],
                memoryHistory: [Double],
                gpuHistory: [Double],
                downloadHistory: [Double],
                uploadHistory: [Double]) {
        self.snapshot = snapshot
        self.cpuHistory = cpuHistory
        self.memoryHistory = memoryHistory
        self.gpuHistory = gpuHistory
        self.downloadHistory = downloadHistory
        self.uploadHistory = uploadHistory
        needsLayout = true
        needsDisplay = true
        layoutSubtreeIfNeeded()
        updateCharts()
    }

    private var cardWidth: CGFloat {
        max(1, (bounds.width - inset * 2 - gap) / 2)
    }

    private var cardHeight: CGFloat {
        max(1, (bounds.height - inset * 2 - gap) / 2)
    }

    private func cardRects() -> [NSRect] {
        let width = cardWidth
        let height = cardHeight
        return [
            NSRect(x: inset, y: inset, width: width, height: height),
            NSRect(x: inset + width + gap, y: inset, width: width, height: height),
            NSRect(x: inset, y: inset + height + gap, width: width, height: height),
            NSRect(x: inset + width + gap, y: inset + height + gap, width: width, height: height)
        ]
    }

    override func layout() {
        super.layout()
        let rects = cardRects()
        guard cardWidth > 20, cardHeight > 30 else { return }
        for index in 0..<3 {
            let card = rects[index]
            charts[index].frame = NSRect(x: card.minX + 10,
                                         y: card.maxY - chartHeight - 9,
                                         width: card.width - 20,
                                         height: chartHeight)
        }
        let network = rects[3]
        let networkChart = NSRect(x: network.minX + 10,
                                  y: network.maxY - chartHeight - 9,
                                  width: network.width - 20,
                                  height: chartHeight)
        charts[3].frame = networkChart
        charts[4].frame = networkChart
        updateCharts()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8).fill()

        guard let snapshot else {
            drawString(L("系统负载"), at: CGPoint(x: inset, y: inset), font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
            return
        }

        let rects = cardRects()
        let primary = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
        }
        let secondary = primary.withAlphaComponent(0.58)

        drawCard(rects[0],
                 title: "CPU",
                 value: percent(snapshot.cpuFraction),
                 detail: L("%@ 核", "\(snapshot.coreCount)"),
                 primary: primary,
                 secondary: secondary)
        drawCard(rects[1],
                 title: L("内存"),
                 value: percent(memoryFraction(snapshot)),
                 detail: snapshot.memoryPressure.title,
                 primary: primary,
                 secondary: secondary)
        drawCard(rects[2],
                 title: "GPU",
                 value: snapshot.gpu.map { percent($0.utilizationFraction) } ?? "—",
                 detail: snapshot.gpu == nil ? L("不可用") : L("利用率"),
                 primary: primary,
                 secondary: secondary)
        drawCard(rects[3],
                 title: L("网络"),
                 value: snapshot.network.map { rate($0.downloadBytesPerSecond) } ?? "—",
                 detail: snapshot.network.map { "↑ " + rate($0.uploadBytesPerSecond) } ?? "",
                 primary: primary,
                 secondary: secondary)
    }

    private func drawCard(_ rect: NSRect,
                          title: String,
                          value: String,
                          detail: String,
                          primary: NSColor,
                          secondary: NSColor) {
        NSColor.labelColor.withAlphaComponent(0.045).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()

        drawString(title, at: CGPoint(x: rect.minX + 10, y: rect.minY + 8),
                   font: .systemFont(ofSize: 10.5), color: secondary)
        drawString(value, at: CGPoint(x: rect.minX + 10, y: rect.minY + 22),
                   font: .monospacedDigitSystemFont(ofSize: 20, weight: .medium), color: primary)

        let detailAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: secondary
        ]
        let detailSize = (detail as NSString).size(withAttributes: detailAttrs)
        (detail as NSString).draw(at: NSPoint(x: rect.maxX - 10 - detailSize.width, y: rect.minY + 9),
                                  withAttributes: detailAttrs)
    }

    private func drawString(_ text: String, at point: CGPoint, font: NSFont, color: NSColor) {
        (text as NSString).draw(at: point, withAttributes: [
            .font: font,
            .foregroundColor: color
        ])
    }

    private func updateCharts() {
        charts[0].apply(values: cpuHistory, color: Theme.chartCPU,
                        minimumSpan: 0.06, interval: SystemLoadMonitor.refreshInterval)
        charts[1].apply(values: memoryHistory, color: Theme.chartMemory,
                        minimumSpan: 0.025, interval: SystemLoadMonitor.refreshInterval)
        charts[2].apply(values: gpuHistory, color: Theme.chartGPU,
                        minimumSpan: 0.08, interval: SystemLoadMonitor.refreshInterval)
        let networkSpan: Double = 128 * 1024
        charts[3].apply(values: downloadHistory, color: Theme.accent,
                        minimumSpan: networkSpan, interval: SystemLoadMonitor.refreshInterval)
        charts[4].apply(values: uploadHistory, color: Theme.chartMemory,
                        minimumSpan: networkSpan, interval: SystemLoadMonitor.refreshInterval)
    }

    private func memoryFraction(_ snapshot: SystemLoadSnapshot) -> Double {
        guard snapshot.memoryTotalBytes > 0 else { return 0 }
        return Double(snapshot.memoryUsedBytes) / Double(snapshot.memoryTotalBytes)
    }

    private func rate(_ bytesPerSecond: Double) -> String {
        let clamped = max(0, bytesPerSecond)
        return Format.bytes(Int64(clamped.rounded())) + "/s"
    }

    private func percent(_ fraction: Double) -> String {
        String(format: "%.0f%%", (max(0, fraction) * 100).rounded())
    }
}
