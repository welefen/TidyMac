import SwiftUI
import AppKit

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var updater: UpdateManager

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: Theme.sidebarWidth)

            ZStack {
                AuroraBackground()
                    .allowsHitTesting(false)
                pageContent
                    .transition(.opacity)
                    .id(app.page)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .preferredColorScheme(preferredColorScheme)
        .onAppear { applyWindowAppearance(settings.appearance) }
        .task { await updater.startOnLaunch(isDemo: app.isDemo) }
        .onChange(of: settings.appearance) { _, appearance in
            applyWindowAppearance(appearance)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func applyWindowAppearance(_ appearance: AppAppearance) {
        let nsAppearance: NSAppearance?
        switch appearance {
        case .system: nsAppearance = nil
        case .light: nsAppearance = NSAppearance(named: .aqua)
        case .dark: nsAppearance = NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = nsAppearance
        for window in NSApp.windows {
            window.appearance = nsAppearance
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch app.page {
        case .overview:
            DashboardPage()
        case .smartScan:
            SmartScanPage()
        case .uninstaller:
            UninstallerPage()
        case .largeFiles:
            LargeFilesPage()
        case .spaceLens:
            SpaceLensPage()
        case .systemLoad:
            SystemLoadPage()
        case .about:
            AboutPage()
        case .settings:
            SettingsPage()
        }
    }
}
