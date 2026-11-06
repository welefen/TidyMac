import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

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
        case .settings:
            SettingsPage()
        }
    }
}
