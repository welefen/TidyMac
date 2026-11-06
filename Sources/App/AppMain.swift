import SwiftUI
import AppKit

@main
struct QingyuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup("清羽") {
            RootView()
                .environmentObject(appState)
                .environmentObject(settings)
                .frame(minWidth: Theme.windowMinWidth, minHeight: Theme.windowMinHeight)
                .preferredColorScheme(.dark)
                .background(WindowConfigurator().frame(width: 0, height: 0).allowsHitTesting(false))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("关于清羽") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "清羽",
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Window styling

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let probe = WindowProbeView()
        probe.onWindow = { window in
            window.title = "清羽"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(Theme.background)
            window.appearance = NSAppearance(named: .darkAqua)
            window.minSize = NSSize(width: Theme.windowMinWidth, height: Theme.windowMinHeight)
            window.setContentSize(NSSize(width: 1200, height: 780))
            window.center()
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            window.standardWindowButton(.zoomButton)?.isHidden = false
        }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowProbeView: NSView {
    var onWindow: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindow?(window)
        }
    }
}
