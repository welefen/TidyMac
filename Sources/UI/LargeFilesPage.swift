import SwiftUI

struct LargeFilesPage: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "大文件", subtitle: "找出最占空间的文件")
                EmptyStateView(symbol: "doc.zipper", title: "大文件", message: "页面正在加载…")
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
        }
    }
}
