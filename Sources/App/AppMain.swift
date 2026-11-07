import SwiftUI
import AppKit

@main
struct TidyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var updater = UpdateManager.shared

    var body: some Scene {
        WindowGroup("TidyMac") {
            RootView()
                .environmentObject(appState)
                .environmentObject(settings)
                .environmentObject(updater)
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
                        .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                        .credits: aboutCredits()
                    ])
                }
            }
            CommandGroup(after: .appInfo) {
                Button("检查更新…") {
                    appState.navigate(to: .settings)
                    NSApp.activate(ignoringOtherApps: true)
                    if case .ready = updater.phase { return }
                    Task { await updater.check(manual: true) }
                }
                .disabled(updateCheckDisabled)
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

    private var updateCheckDisabled: Bool {
        switch updater.phase {
        case .checking, .available, .downloading, .installing:
            return true
        default:
            return false
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

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            Analytics.shared.track(.appEnd, [
                "duration_ms": .int(Analytics.shared.sessionDurationMilliseconds)
            ])
            // Best effort: anything still queued is persisted and retried on the
            // next launch, so quitting never blocks for long.
            Analytics.shared.flush(timeout: 1.5)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Window styling



// MARK: - Window styling


private func aboutCredits() -> NSAttributedString {
    let tagline = L("轻净如羽，焕然一新。\nmacOS 智能清理与空间管理工具")
    let text = L("作者：") + "@welefen\n" + tagline
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineSpacing = 2
    let credits = NSMutableAttributedString(string: text, attributes: [.paragraphStyle: style])
    if let range = text.range(of: "@welefen") {
        credits.addAttributes([
            .link: URL(string: "https://github.com/welefen")!,
            .foregroundColor: NSColor.linkColor
        ], range: NSRange(range, in: text))
    }
    return credits
}
