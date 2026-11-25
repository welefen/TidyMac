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
        trendsView.frame = NSRect(x: 0, y: 0, width: 340, height: 124)
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
            trendsView.update(snapshot: nil, cpuHistory: [], memoryHistory: [], gpuHistory: [])
            return
        }

        let cpu = Int((snapshot.cpuFraction * 100).rounded())
        statusItem.button?.attributedTitle = cpuTitle(for: cpu)
        statusItem.button?.toolTip = L("CPU %@", "\(cpu)%")
        trendsView.update(
            snapshot: snapshot,
            cpuHistory: monitor.cpuHistory,
            memoryHistory: monitor.memoryHistory,
            gpuHistory: monitor.gpuHistory
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
    private var snapshot: SystemLoadSnapshot?
    private var cpuHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private var gpuHistory: [Double] = []

    private let insetX: CGFloat = 12
    private let insetY: CGFloat = 7
    private let textHeight: CGFloat = 15
    private let chartHeight: CGFloat = 18
    private let rowGap: CGFloat = 6
    private let charts: [TrendHostView] = (0..<3).map { _ in
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
    }

    required init?(coder: NSCoder) { nil }

    func update(snapshot: SystemLoadSnapshot?,
                cpuHistory: [Double],
                memoryHistory: [Double],
                gpuHistory: [Double]) {
        self.snapshot = snapshot
        self.cpuHistory = cpuHistory
        self.memoryHistory = memoryHistory
        self.gpuHistory = gpuHistory
        needsLayout = true
        needsDisplay = true
        layoutSubtreeIfNeeded()
        updateCharts()
    }

    override func layout() {
        super.layout()
        let width = bounds.width - insetX * 2
        guard width > 1 else { return }
        let rowHeight = textHeight + chartHeight + rowGap
        for (index, chart) in charts.enumerated() {
            let top = insetY + CGFloat(index) * rowHeight + textHeight
            chart.frame = NSRect(x: insetX, y: top, width: width, height: chartHeight)
        }
        updateCharts()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6).fill()

        guard snapshot != nil else {
            drawText(label: L("系统负载"), value: "—", x: insetX, y: insetY)
            return
        }

        let width = bounds.width - insetX * 2
        guard width > 1 else { return }
        let rowHeight = textHeight + chartHeight + rowGap

        for index in 0..<3 {
            let top = insetY + CGFloat(index) * rowHeight
            drawText(label: label(for: index), value: value(for: index), x: insetX, y: top)
        }
    }

    private func updateCharts() {
        let width = bounds.width - insetX * 2
        guard width > 1 else { return }
        charts[0].apply(values: Array(cpuHistory.suffix(SystemLoadMonitor.displayCapacity + 1)),
                        color: Theme.accent,
                        minimumSpan: 0.06,
                        interval: SystemLoadMonitor.refreshInterval)
        charts[1].apply(values: Array(memoryHistory.suffix(SystemLoadMonitor.displayCapacity + 1)),
                        color: Theme.accent,
                        minimumSpan: 0.025,
                        interval: SystemLoadMonitor.refreshInterval)
        charts[2].apply(values: Array(gpuHistory.suffix(SystemLoadMonitor.displayCapacity + 1)),
                        color: Theme.accent,
                        minimumSpan: 0.08,
                        interval: SystemLoadMonitor.refreshInterval)
    }

    private func label(for index: Int) -> String {
        switch index {
        case 0: return "CPU"
        case 1: return L("内存")
        default: return "GPU"
        }
    }

    private func value(for index: Int) -> String {
        guard let snapshot else { return "—" }
        switch index {
        case 0:
            return L("%@ · %@ 核", percent(snapshot.cpuFraction), "\(snapshot.coreCount)")
        case 1:
            return L("%@ / %@ · %@",
                     Format.bytes(snapshot.memoryUsedBytes),
                     Format.bytes(snapshot.memoryTotalBytes),
                     snapshot.memoryPressure.title)
        default:
            if let gpu = snapshot.gpu {
                return L("%@ · %@", percent(gpu.utilizationFraction), L("利用率"))
            }
            return L("不可用")
        }
    }

    private func drawText(label: String, value: String, x: CGFloat, y: CGFloat) {
        let primary = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .black
        }
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: primary.withAlphaComponent(0.62)
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: primary
        ]
        let labelText = label as NSString
        labelText.draw(at: NSPoint(x: x, y: y + 1), withAttributes: labelAttributes)
        let labelWidth = labelText.size(withAttributes: labelAttributes).width
        (value as NSString).draw(at: NSPoint(x: x + labelWidth + 4, y: y + 1),
                                 withAttributes: valueAttributes)
    }

    private func percent(_ fraction: Double) -> String {
        String(format: "%.0f%%", (max(0, fraction) * 100).rounded())
    }
}
