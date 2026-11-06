import SwiftUI
import AppKit

@main
struct TidyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup("TidyMac") {
            RootView()
                .environmentObject(appState)
                .environmentObject(settings)
                .frame(minWidth: Theme.windowMinWidth, minHeight: Theme.windowMinHeight)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("关于 TidyMac") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "TidyMac",
                        .applicationVersion: "1.0.0",
                        .credits: NSAttributedString(string: "轻净如羽，焕然一新。\n一款为 macOS 打造的智能清理与空间管理工具。")
                    ])
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    appState.navigate(to: .settings)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("清理") {
                Button("开始智能扫描") { appState.startSmartScan() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(appState.isScanning || appState.isCleaning)
                Button("取消扫描") { appState.cancelScan() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!appState.isScanning)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var configuredWindows = Set<ObjectIdentifier>()
    private var keyWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Style the SwiftUI window from the outside instead of placing an
        // NSViewRepresentable inside the view tree. A representable used as a
        // background can become an invisible hit-testing layer over the window,
        // which previously made the sidebar unresponsive to mouse clicks.
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            self?.configure(window)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            for window in NSApp.windows {
                self?.configure(window)
            }
        }
    }

    private func configure(_ window: NSWindow) {
        let identifier = ObjectIdentifier(window)
        guard !configuredWindows.contains(identifier), window.canBecomeMain else { return }
        configuredWindows.insert(identifier)

        window.title = "TidyMac"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: Theme.windowMinWidth, height: Theme.windowMinHeight)
        window.setContentSize(NSSize(width: 1200, height: 780))
        window.center()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Window styling



// MARK: - Window styling
