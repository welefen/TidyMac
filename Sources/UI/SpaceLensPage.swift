import SwiftUI
import AppKit

// MARK: - Root choice

enum SpaceRootOption: String, CaseIterable, Identifiable {
    case home
    case downloads
    case applications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "主目录"
        case .downloads: return "下载"
        case .applications: return "应用程序"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .applications: return "square.grid.2x2.fill"
        }
    }

    var url: URL {
        switch self {
        case .home: return HomePaths.home
        case .downloads: return HomePaths.url("Downloads")
        case .applications: return URL(fileURLWithPath: "/Applications")
        }
    }
}

// MARK: - View model

@MainActor
final class SpaceLensViewModel: ObservableObject {
    @Published var path: [SpaceNode] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanStatus = "正在准备扫描…"
    @Published var hasLoaded = false
    @Published var scanError: String?
    @Published var rootLabel = "主目录"

    private var scanTask: Task<Void, Never>?
    private var scanRoot: URL = HomePaths.home
    private var demoMode = false

    // MARK: Derived

    var current: SpaceNode? { path.last }

    var childrenSorted: [SpaceNode] {
        (current?.children ?? []).sorted { $0.byteCount > $1.byteCount }
    }

    var directoryCount: Int {
        childrenSorted.filter(\.isDirectory).count
    }

    var largestChild: SpaceNode? { childrenSorted.first }

    var canGoBack: Bool { path.count > 1 }

    // MARK: Loading

    func load(isDemo: Bool) {
        guard !hasLoaded else { return }
        if isDemo {
            applyDemoTree()
        } else {
            startScan(root: HomePaths.home)
        }
    }

    func rescan(isDemo: Bool) {
        if isDemo {
            applyDemoTree()
        } else {
            startScan(root: scanRoot)
        }
    }

    func load(root option: SpaceRootOption, isDemo: Bool) {
        rootLabel = option.title
        scanRoot = option.url
        if isDemo {
            applyDemoTree()
        } else {
            startScan(root: option.url)
        }
    }

    func load(customRoot url: URL, isDemo: Bool) {
        rootLabel = url.lastPathComponent
        scanRoot = url
        if isDemo {
            applyDemoTree()
        } else {
            startScan(root: url)
        }
    }

    private func applyDemoTree() {
        scanTask?.cancel()
        demoMode = true
        isScanning = false
        scanProgress = 1
        scanStatus = "分析完成"
        scanError = nil
        hasLoaded = true
        path = [DemoData.spaceTree]
    }

    func startScan(root: URL) {
        scanTask?.cancel()
        demoMode = false
        scanError = nil
        isScanning = true
        scanProgress = 0.02
        scanStatus = L("正在分析 \(root.lastPathComponent)…")

        scanTask = Task { [weak self] in
            guard let self else { return }
            let node = await SpaceLensEngine.scan(root: root, maxDepth: 2) { progress, status in
                Task { @MainActor [weak self] in
                    guard let self, self.isScanning else { return }
                    self.scanProgress = progress
                    self.scanStatus = status
                }
            }
            guard !Task.isCancelled else { return }
            self.isScanning = false
            self.scanProgress = 1
            self.scanStatus = "分析完成"
            self.hasLoaded = true
            if node.children.isEmpty && node.byteCount == 0 {
                self.scanError = "未能读取该目录，可能是权限不足或目录为空。"
            }
            self.path = [node]
            Analytics.shared.track(.spaceLensScan, [
                "child_count": .int(Int64(node.childCount)),
                "bytes_scanned": .int(node.byteCount)
            ])
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
        hasLoaded = path.isEmpty ? false : true
    }

    // MARK: Navigation

    func enter(_ node: SpaceNode) {
        guard node.isDirectory else { return }
        if !node.children.isEmpty {
            path.append(node)
            return
        }
        guard !demoMode, node.canDrillInLens else { return }
        drillInto(node)
    }

    /// The initial scan is intentionally shallow. When the user opens a folder
    /// at the deepest scanned level, scan just that subtree and append it to the
    /// existing breadcrumb path instead of restarting from the lens root.
    private func drillInto(_ node: SpaceNode) {
        scanTask?.cancel()
        scanError = nil
        isScanning = true
        scanProgress = 0.02
        scanStatus = L("正在分析 \(node.name)…")
        let basePath = path

        scanTask = Task { [weak self] in
            guard let self else { return }
            let scanned = await SpaceLensEngine.scan(root: node.url, maxDepth: 2) { progress, status in
                Task { @MainActor [weak self] in
                    guard let self, self.isScanning else { return }
                    self.scanProgress = progress
                    self.scanStatus = status
                }
            }
            guard !Task.isCancelled else { return }
            self.isScanning = false
            self.scanProgress = 1
            self.scanStatus = "分析完成"
            self.hasLoaded = true
            if scanned.children.isEmpty && scanned.byteCount == 0 {
                self.scanError = "未能读取该目录，可能是权限不足或目录为空。"
                self.path = basePath
            } else {
                self.path = basePath + [scanned]
            }
        }
    }

    func pop(to index: Int) {
        guard index >= 0, index < path.count else { return }
        if index == path.count - 1 { return }
        path = Array(path.prefix(index + 1))
    }

    func goBack() {
        guard path.count > 1 else { return }
        path.removeLast()
    }
}

// MARK: - Page

struct SpaceLensPage: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var model = SpaceLensViewModel()
    @State private var hoveredRankID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "空间透镜", subtitle: "看清每一 GB 的去向") {
                HStack(spacing: 10) {
                    rootMenu
                    rescanButton
                }
            }

            if model.isScanning {
                scanningContent
            } else if let current = model.current {
                breadcrumbRow(current)
                statsRow(current)
                if current.children.isEmpty {
                    emptyContent(current)
                } else {
                    treemapPanel(current)
                    rankingPanel(current)
                }
            } else {
                initialContent
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 30)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.24), value: model.path.count)
        .animation(.easeInOut(duration: 0.24), value: model.isScanning)
        .onAppear {
            model.load(isDemo: app.isDemo)
        }
    }

    // MARK: Header controls

    private var rootMenu: some View {
        Menu {
            ForEach(SpaceRootOption.allCases) { option in
                Button {
                    model.load(root: option, isDemo: app.isDemo)
                } label: {
                    Label(option.title, systemImage: option.symbol)
                }
            }
            Divider()
            Button {
                chooseFolder()
            } label: {
                Label("选择文件夹…", systemImage: "folder.badge.plus")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(L(model.rootLabel))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule(style: .continuous).fill(Theme.cardElevated))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(model.isScanning)
    }

    private var rescanButton: some View {
        Button {
            model.rescan(isDemo: app.isDemo)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text(L("重新扫描"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(Capsule(style: .continuous).fill(Theme.cardElevated))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(model.isScanning)
        .opacity(model.isScanning ? 0.5 : 1)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = L("分析")
        panel.message = L("选择要分析空间占用的文件夹")
        if panel.runModal() == .OK, let url = panel.url {
            model.load(customRoot: url, isDemo: app.isDemo)
        }
    }

    // MARK: Breadcrumb

    private func breadcrumbRow(_ current: SpaceNode) -> some View {
        HStack(spacing: 10) {
            SpaceLensBreadcrumb(path: model.path) { index in
                model.pop(to: index)
            }
            Text(Format.itemCount(current.children.count))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: Stats

    private func statsRow(_ current: SpaceNode) -> some View {
        let total = Format.bytesParts(current.byteCount)
        let largestParts = Format.bytesParts(model.largestChild?.byteCount ?? 0)
        return HStack(spacing: 12) {
            LensStatCard(title: "当前目录总大小",
                         value: total.number,
                         unit: total.unit,
                         caption: current.name,
                         symbol: "internaldrive.fill",
                         tone: .mint)
            LensStatCard(title: "目录数量",
                         value: "\(model.directoryCount)",
                         unit: "个",
                         caption: L("共 \(current.children.count) 个项目"),
                         symbol: "folder.fill",
                         tone: .blue)
            LensStatCard(title: "最大项目",
                         value: largestParts.number,
                         unit: largestParts.unit,
                         caption: model.largestChild?.name ?? "—",
                         symbol: "arrow.up.right.circle.fill",
                         tone: .purple)
        }
    }

    // MARK: Treemap

    private func treemapPanel(_ current: SpaceNode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L("空间分布"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("点击色块进入下一层"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(L("按占用从多到少排列"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            SpaceTreemapView(node: current) { node in
                model.enter(node)
            }
            .frame(height: 234)
        }
        .qyPanel(padding: 14)
    }

    // MARK: Ranking

    private func rankingPanel(_ current: SpaceNode) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L("空间排行"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("点击目录进入"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text(L("共 \(current.children.count) 项"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)

            DividerLine()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.childrenSorted.enumerated()), id: \.element.id) { index, node in
                        SpaceRankRowView(node: node,
                                         tone: SpaceLensPalette.tone(at: index),
                                         fraction: fraction(of: node, in: current),
                                         isLast: index == model.childrenSorted.count - 1,
                                         isHovered: hoveredRankID == node.id,
                                         onEnter: { model.enter(node) },
                                         onReveal: {
                                             NSWorkspace.shared.activateFileViewerSelecting([node.url])
                                         })
                            .onHover { hovering in
                                if hovering {
                                    hoveredRankID = node.id
                                } else if hoveredRankID == node.id {
                                    hoveredRankID = nil
                                }
                            }
                    }
                }
                .padding(.vertical, 3)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color.clear, Theme.card],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
                    .allowsHitTesting(false)
            }
        }
        .qyPanel(padding: 0)
        .frame(maxHeight: .infinity)
    }

    private func fraction(of node: SpaceNode, in parent: SpaceNode) -> Double {
        guard parent.byteCount > 0 else { return 0 }
        return min(1, max(0, Double(node.byteCount) / Double(parent.byteCount)))
    }

    // MARK: States

    private var scanningContent: some View {
        VStack {
            SpaceLensScanningView(progress: model.scanProgress,
                                  status: model.scanStatus) {
                model.cancelScan()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private func emptyContent(_ current: SpaceNode) -> some View {
        VStack {
            EmptyStateView(symbol: model.scanError == nil ? "folder" : "lock.shield.fill",
                           title: model.scanError == nil ? "此目录没有可分析的项目" : "无法读取该目录",
                           message: model.scanError ?? "该目录为空，或其中的项目没有可统计的磁盘占用。",
                           actionTitle: model.canGoBack ? "返回上级" : "重新扫描") {
                if model.canGoBack {
                    model.goBack()
                } else {
                    model.rescan(isDemo: app.isDemo)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private var initialContent: some View {
        VStack {
            EmptyStateView(symbol: "circle.hexagongrid.fill",
                           title: "选择一个目录开始分析",
                           message: "空间透镜会把目录大小画成色块，帮助你一眼看出空间被什么占用。",
                           actionTitle: "扫描主目录") {
                model.load(root: .home, isDemo: app.isDemo)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
