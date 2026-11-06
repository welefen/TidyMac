import SwiftUI

struct SettingsPage: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "设置", subtitle: "清理偏好与排除项")
                EmptyStateView(symbol: "gearshape.fill", title: "设置", message: "页面正在加载…")
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
        }
    }
}
