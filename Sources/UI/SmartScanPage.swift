import SwiftUI

struct SmartScanPage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "智能扫描", subtitle: "扫描并清理无用文件") {
                QYAvailableSpacePill(disk: app.disk)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 30)
            .padding(.bottom, 18)

            phaseContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            if let notice = app.exclusionNotice {
                ScanExclusionBanner(notice: notice,
                                    onUndo: { app.undoExclusion() },
                                    onDismiss: { app.dismissExclusionNotice() })
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, 74)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: app.exclusionNotice?.id)
        .animation(.easeInOut(duration: 0.25), value: app.phase)
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch app.phase {
        case .idle:
            ScanIdleView()
        case .scanning:
            ScanRunningView()
        case .results:
            if let result = app.scanResult, result.totalItemCount > 0 {
                ScanResultsView(result: result)
            } else {
                ScanEmptyResultsView()
            }
        case .cleaning:
            ScanCleaningView()
        case .finished:
            ScanFinishedView()
        }
    }
}
