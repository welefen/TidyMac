import AppKit
import Combine

extension Notification.Name {
    static let tidymacOpenSystemLoad = Notification.Name("tidymac.openSystemLoad")
}

private final class FallbackBarView: NSVisualEffectView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

/// A compact live CPU / memory readout in the macOS menu bar.
///
/// It runs its own lightweight sampler (`includeApps: false`) so the menu bar
/// never pays for enumerating every process. Clicking the item opens a small
/// menu with the detailed numbers and shortcuts back into the app.
final class MenuBarStatsController: NSObject {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let monitor = SystemLoadMonitor()
    private var cancellable: AnyCancellable?
    private var fallbackPanel: NSPanel?
    private var fallbackLabel: NSTextField?

    private let cpuMenuItem = NSMenuItem(title: L("CPU"), action: nil, keyEquivalent: "")
    private let memoryMenuItem = NSMenuItem(title: L("内存"), action: nil, keyEquivalent: "")

    override init() {
        super.init()
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
        monitor.start(isDemo: false, includeApps: false)

        // macOS 26 StatusKit may register the item but never composite it.
        // If it is still not on screen shortly after launch, fall back to a
        // small always-on-top readout pinned below the menu bar.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            self?.showFallbackIfNeeded()
        }
    }

    func stop() {
        monitor.stop()
        cancellable?.cancel()
        cancellable = nil
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.setAccessibilityIdentifier("com.tidymac.clean.statusItemButton")
            button.setAccessibilityTitle("TidyMac")
            button.setAccessibilityLabel("TidyMac CPU 与内存")

            let symbol = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: L("系统负载"))
            symbol?.isTemplate = true
            button.image = symbol
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
            button.title = "—"
            button.toolTip = L("CPU 与内存使用情况")
        }
        item.menu = menu
        statusItem = item
        apply(monitor.snapshot)
    }

    private func buildMenu() {
        cpuMenuItem.isEnabled = false
        memoryMenuItem.isEnabled = false
        menu.addItem(cpuMenuItem)
        menu.addItem(memoryMenuItem)
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

        let hideFallback = NSMenuItem(title: L("隐藏悬浮窗"),
                                      action: #selector(hideFallback),
                                      keyEquivalent: "")
        hideFallback.target = self
        menu.addItem(hideFallback)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("退出 TidyMac"),
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func apply(_ snapshot: SystemLoadSnapshot?) {
        guard let snapshot else {
            statusItem.button?.title = "—"
            return
        }

        let cpu = Int((snapshot.cpuFraction * 100).rounded())
        let memory = Self.compactMemory(snapshot.memoryUsedBytes)
        statusItem.button?.title = "\(cpu)% \(memory)"
        statusItem.button?.toolTip = L("CPU %@ · 内存 %@",
                                       "\(cpu)%",
                                       Format.bytes(snapshot.memoryUsedBytes))

        fallbackLabel?.stringValue = "\(cpu)%  \(memory)"
        cpuMenuItem.title = L("CPU %@ · %@ 核", "\(cpu)%", "\(snapshot.coreCount)")
        memoryMenuItem.title = L("内存 %@ / %@ · %@",
                                 Format.bytes(snapshot.memoryUsedBytes),
                                 Format.bytes(snapshot.memoryTotalBytes),
                                 snapshot.memoryPressure.title)
    }

    private static func compactMemory(_ bytes: Int64) -> String {
        let gib = Double(bytes) / 1_073_741_824
        if gib >= 1 { return String(format: "%.1fG", gib) }
        return "\(max(1, Int((Double(bytes) / 1_048_576).rounded())))M"
    }

    private func statusItemIsVisible() -> Bool {
        guard let window = statusItem.button?.window,
              window.frame.origin.y > 0 else { return false }
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let number = window.windowNumber
        return windows.contains { ($0[kCGWindowNumber as String] as? Int) == number }
    }

    private func showFallbackIfNeeded() {
        guard !statusItemIsVisible(), fallbackPanel == nil else { return }

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 176, height: 26),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        let effect = FallbackBarView()
        effect.onClick = { [weak self] in self?.showFallbackMenu() }
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 13
        effect.layer?.masksToBounds = true

        let image = NSImageView()
        image.image = NSImage(systemSymbolName: "gauge.medium",
                              accessibilityDescription: L("系统负载"))
        image.contentTintColor = .labelColor
        image.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "—")
        label.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        fallbackLabel = label

        effect.addSubview(image)
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 10),
            image.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 14),
            image.heightAnchor.constraint(equalToConstant: 14),
            label.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: effect.centerYAnchor)
        ])

        panel.contentView = effect
        fallbackPanel = panel

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 186, y: frame.maxY - 30))
        }
        panel.orderFrontRegardless()
    }

    @objc private func showFallbackMenu() {
        guard let panel = fallbackPanel, let content = panel.contentView else { return }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 4, y: content.bounds.height - 4),
                   in: content)
    }

    @objc private func hideFallback() {
        fallbackPanel?.orderOut(nil)
        fallbackPanel = nil
        fallbackLabel = nil
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
