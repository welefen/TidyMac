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

    private let cpuMenuItem = NSMenuItem(title: L("CPU"), action: nil, keyEquivalent: "")
    private let memoryMenuItem = NSMenuItem(title: L("内存"), action: nil, keyEquivalent: "")

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
        statusItem.button?.attributedTitle = cpuTitle(for: cpu)
        statusItem.button?.toolTip = L("CPU %@", "\(cpu)%")
        cpuMenuItem.title = L("CPU %@ · %@ 核", "\(cpu)%", "\(snapshot.coreCount)")
        memoryMenuItem.title = L("内存 %@ / %@ · %@",
                                 Format.bytes(snapshot.memoryUsedBytes),
                                 Format.bytes(snapshot.memoryTotalBytes),
                                 snapshot.memoryPressure.title)
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
