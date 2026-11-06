import SwiftUI

struct UninstallerPage: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "卸载器", subtitle: "彻底移除应用及残留")
                EmptyStateView(symbol: "trash.slash.fill", title: "卸载器", message: "页面正在加载…")
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
        }
    }
}
