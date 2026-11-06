import SwiftUI

struct SpaceLensPage: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "空间透镜", subtitle: "看清每一 GB 的去向")
                EmptyStateView(symbol: "circle.hexagongrid.fill", title: "空间透镜", message: "页面正在加载…")
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
        }
    }
}
