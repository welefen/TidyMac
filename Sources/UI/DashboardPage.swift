import SwiftUI

struct DashboardPage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "总览", subtitle: "让 Mac 轻净如羽") {
                    Button("开始扫描") { app.startSmartScan() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Text("Dashboard coming online…")
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
            .padding(.bottom, 40)
        }
    }
}
