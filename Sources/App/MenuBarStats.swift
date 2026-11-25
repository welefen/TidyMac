import AppKit
import Combine

extension Notification.Name {
    static let tidymacOpenSystemLoad = Notification.Name("tidymac.openSystemLoad")
}

/// A compact live CPU / memory readout in the macOS menu bar.
///
/// It runs its own lightweight sampler (`includeApps: false`) so the menu bar
/// never pays for enumerating every process. Clicking the item opens a small
/// menu with the detailed numbers and shortcuts back into the app.
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

        // macOS 26 (Tahoe) routes third-party menu bar items through
        // ControlCenter's StatusKit approval list. A freshly created item can
        // be registered but never composited until ControlCenter has picked
        // it up, so give it a moment and recreate once if it is still hidden.

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
        trendsView.frame = NSRect(x: 0, y: 0, width: 340, height: 124)
        trendsItem.view = trendsView
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

/// Compact CPU/memory/GPU trend block used at the top of the menu bar menu.
/// It is drawn with AppKit so opening the menu doesn't spin up SwiftUI.
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

    override var isFlipped: Bool { true }

    func update(snapshot: SystemLoadSnapshot?, cpuHistory: [Double],
                memoryHistory: [Double], gpuHistory: [Double]) {
        self.snapshot = snapshot
        self.cpuHistory = cpuHistory
        self.memoryHistory = memoryHistory
        self.gpuHistory = gpuHistory
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let snapshot else {
            drawText(L("系统负载"), value: "—", y: insetY, width: bounds.width - insetX * 2)
            return
        }

        let width = bounds.width - insetX * 2
        var y = insetY
        drawRow(label: "CPU",
                value: L("%@ · %@ 核", percent(snapshot.cpuFraction), "\(snapshot.coreCount)"),
                history: cpuHistory, minimumSpan: 0.06,
                x: insetX, y: y, width: width)
        y += textHeight + chartHeight + rowGap

        drawRow(label: L("内存"),
                value: L("%@ / %@ · %@",
                         Format.bytes(snapshot.memoryUsedBytes),
                         Format.bytes(snapshot.memoryTotalBytes),
                         snapshot.memoryPressure.title),
                history: memoryHistory, minimumSpan: 0.025,
                x: insetX, y: y, width: width)
        y += textHeight + chartHeight + rowGap

        if let gpu = snapshot.gpu {
            drawRow(label: "GPU",
                    value: L("%@ · %@", percent(gpu.utilizationFraction), L("利用率")),
                    history: gpuHistory, minimumSpan: 0.08,
                    x: insetX, y: y, width: width)
        } else {
            drawRow(label: "GPU", value: L("不可用"),
                    history: [], minimumSpan: 0.08,
                    x: insetX, y: y, width: width)
        }
    }

    private func drawRow(label: String, value: String, history: [Double],
                         minimumSpan: Double, x: CGFloat, y: CGFloat, width: CGFloat) {
        drawText(label, value: value, y: y, width: width)

        let chartRect = NSRect(x: x, y: y + textHeight, width: width, height: chartHeight)
        let radius: CGFloat = 4
        NSColor.labelColor.withAlphaComponent(0.06).setFill()
        NSBezierPath(roundedRect: chartRect, xRadius: radius, yRadius: radius).fill()
        guard history.count >= 2 else { return }

        let values = Array(history.suffix(SystemLoadMonitor.displayCapacity))
        let lowerValue = values.min() ?? 0
        let upperValue = values.max() ?? 1
        let mid = (lowerValue + upperValue) / 2
        let span = max(upperValue - lowerValue, minimumSpan)
        let lower = mid - span / 2
        let upper = mid + span / 2

        let step = chartRect.width / CGFloat(SystemLoadMonitor.displayCapacity - 1)
        let startX = chartRect.maxX - CGFloat(values.count - 1) * step
        var points: [NSPoint] = []
        points.reserveCapacity(values.count)
        for (index, value) in values.enumerated() {
            let normalized = min(max((value - lower) / max(upper - lower, 0.0001), 0), 1)
            points.append(NSPoint(
                x: startX + CGFloat(index) * step,
                y: chartRect.maxY - CGFloat(normalized) * chartRect.height
            ))
        }

        let line = NSBezierPath()
        addSmoothPath(points, to: line)

        let area = NSBezierPath()
        area.move(to: NSPoint(x: points[0].x, y: chartRect.maxY))
        area.line(to: points[0])
        for point in points.dropFirst() { area.line(to: point) }
        area.line(to: NSPoint(x: points[points.count - 1].x, y: chartRect.maxY))
        area.close()
        accentColor.withAlphaComponent(0.16).setFill()
        area.fill()

        accentColor.setStroke()
        line.lineWidth = 1.5
        line.lineJoinStyle = .round
        line.lineCapStyle = .round
        line.stroke()
    }

    private func drawText(_ label: String, value: String, y: CGFloat, width: CGFloat) {
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: label + " ", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))
        text.append(NSAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]))
        text.draw(in: NSRect(x: insetX, y: y, width: width, height: textHeight))
    }

    private func percent(_ fraction: Double) -> String {
        String(format: "%.0f%%", (max(0, fraction) * 100).rounded())
    }

    private func addSmoothPath(_ points: [NSPoint], to path: NSBezierPath) {
        guard let first = points.first else { return }
        path.move(to: first)
        guard points.count > 1 else { return }
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let c1 = NSPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = NSPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.curve(to: p2, controlPoint1: c1, controlPoint2: c2)
        }
    }

    private var accentColor: NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 0.435, green: 0.827, blue: 0.698, alpha: 1)
                : NSColor(srgbRed: 0.078, green: 0.420, blue: 0.337, alpha: 1)
        }
    }
}
