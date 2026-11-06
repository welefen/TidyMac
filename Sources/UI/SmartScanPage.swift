import SwiftUI

struct SmartScanPage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "智能扫描", subtitle: "扫描并清理无用文件")
                if let result = app.scanResult {
                    Text("发现 \(Format.bytes(result.totalBytesFound)) 可清理空间")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Button("清理选中项") { app.cleanSelected() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("开始扫描") { app.startSmartScan() }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
            .padding(.bottom, 40)
        }
    }
}
