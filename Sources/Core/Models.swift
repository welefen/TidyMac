import Foundation

// MARK: - Navigation

enum AppPage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case smartScan
    case uninstaller
    case largeFiles
    case spaceLens
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "总览"
        case .smartScan: return "智能扫描"
        case .uninstaller: return "卸载器"
        case .largeFiles: return "大文件"
        case .spaceLens: return "空间透镜"
        case .settings: return "设置"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "让 Mac 轻净如羽"
        case .smartScan: return "扫描并清理无用文件"
        case .uninstaller: return "彻底移除应用及残留"
        case .largeFiles: return "找出最占空间的文件"
        case .spaceLens: return "看清每一 GB 的去向"
        case .settings: return "清理偏好与排除项"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .smartScan: return "sparkles"
        case .uninstaller: return "trash.slash.fill"
        case .largeFiles: return "doc.zipper"
        case .spaceLens: return "circle.hexagongrid.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Accent / visual metadata

enum AccentTone: String, Codable, Hashable, Sendable, CaseIterable {
    case mint
    case blue
    case purple
    case orange
    case pink
    case yellow
    case teal
    case red
}

enum SafetyLevel: String, Codable, Hashable, Sendable, CaseIterable {
    /// Cannot break anything meaningful.
    case safe
    /// Rebuildable, but may cost time / re-login.
    case caution
    /// User data or large rebuild cost. Never selected by default.
    case risky

    var label: String {
        switch self {
        case .safe: return "安全"
        case .caution: return "谨慎"
        case .risky: return "重要"
        }
    }
}

enum CleanupGroup: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case systemJunk
    case developerJunk
    case browserJunk
    case mailAttachments
    case iosBackups
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemJunk: return "系统垃圾"
        case .developerJunk: return "开发者垃圾"
        case .browserJunk: return "浏览器数据"
        case .mailAttachments: return "邮件附件"
        case .iosBackups: return "iOS 备份"
        case .trash: return "废纸篓"
        }
    }

    var order: Int {
        switch self {
        case .systemJunk: return 0
        case .developerJunk: return 1
        case .browserJunk: return 2
        case .mailAttachments: return 3
        case .iosBackups: return 4
        case .trash: return 5
        }
    }
}

enum ItemKind: String, Codable, Hashable, Sendable {
    case cache
    case log
    case crashReport
    case savedState
    case trash
    case derivedData
    case deviceSupport
    case simulatorCache
    case packageCache
    case browserCache
    case mailAttachment
    case iosBackup
    case downloadInstaller
    case appLeftover
    case largeFile
    case other
}

// MARK: - Scan models

struct ScanItem: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var urls: [URL]
    var byteCount: Int64
    var kind: ItemKind
    var safety: SafetyLevel
    var detail: String?
    var modifiedAt: Date?
    var isSelected: Bool

    init(id: String? = nil,
         name: String,
         urls: [URL],
         byteCount: Int64,
         kind: ItemKind,
         safety: SafetyLevel,
         detail: String? = nil,
         modifiedAt: Date? = nil,
         isSelected: Bool = true) {
        self.id = id ?? (urls.first?.path ?? "item") + "#" + kind.rawValue
        self.name = name
        self.urls = urls
        self.byteCount = byteCount
        self.kind = kind
        self.safety = safety
        self.detail = detail
        self.modifiedAt = modifiedAt
        self.isSelected = isSelected
    }

    var primaryURL: URL {
        urls.first ?? URL(fileURLWithPath: "/")
    }

    var displayDetail: String? {
        if let detail, !detail.isEmpty { return detail }
        if urls.count > 1 { return "包含 \(urls.count) 个项目" }
        return nil
    }
}

struct ScanCategory: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var subtitle: String
    var symbol: String
    var tone: AccentTone
    var group: CleanupGroup
    var items: [ScanItem]

    init(id: String, title: String, subtitle: String, symbol: String, tone: AccentTone,
         group: CleanupGroup, items: [ScanItem]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tone = tone
        self.group = group
        self.items = items
    }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.byteCount } }
    var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.byteCount } }
    var selectedCount: Int { items.filter(\.isSelected).count }
    var itemCount: Int { items.count }
    var isAllSelected: Bool { !items.isEmpty && items.allSatisfy(\.isSelected) }
    var isPartiallySelected: Bool { items.contains(where: \.isSelected) && !isAllSelected }
}

struct SmartScanResult: Sendable {
    var categories: [ScanCategory]
    var freeBytes: Int64
    var totalBytes: Int64
    var scannedAt: Date
    var duration: TimeInterval

    var totalBytesFound: Int64 { categories.reduce(0) { $0 + $1.totalBytes } }
    var selectedBytes: Int64 { categories.reduce(0) { $0 + $1.selectedBytes } }
    var totalItemCount: Int { categories.reduce(0) { $0 + $1.itemCount } }
    var selectedCount: Int { categories.reduce(0) { $0 + $1.selectedCount } }

    var safeBytes: Int64 {
        categories.reduce(0) { partial, category in
            partial + category.items.filter { $0.safety == .safe && $0.isSelected }.reduce(0) { $0 + $1.byteCount }
        }
    }

    var riskyCount: Int {
        categories.reduce(0) { partial, category in
            partial + category.items.filter { $0.safety == .risky }.count
        }
    }

    func category(id: String) -> ScanCategory? {
        categories.first { $0.id == id }
    }
}

struct ScanProgress: Sendable {
    var fraction: Double
    var status: String
    var detail: String = ""

    static let idle = ScanProgress(fraction: 0, status: "准备就绪")
}

struct CleanProgress: Sendable {
    var fraction: Double
    var status: String

    static let idle = CleanProgress(fraction: 0, status: "")
}

// MARK: - Cleaning models

struct CleanFailure: Identifiable, Sendable, Hashable {
    let path: String
    let reason: String
    var id: String { path + "|" + reason }
}

struct CleanReport: Sendable {
    var removedCount: Int
    var freedBytes: Int64
    var failures: [CleanFailure]
    var completedAt: Date
    var movedToTrash: Bool

    static let empty = CleanReport(removedCount: 0, freedBytes: 0, failures: [],
                                   completedAt: Date(), movedToTrash: true)

    var success: Bool { failures.isEmpty }
}

// MARK: - Disk

struct DiskInfo: Sendable, Equatable {
    var totalBytes: Int64
    var freeBytes: Int64
    var volumeName: String

    var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    var freeFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(freeBytes) / Double(totalBytes)))
    }
    var usedFraction: Double { 1 - freeFraction }

    static let empty = DiskInfo(totalBytes: 0, freeBytes: 0, volumeName: "Macintosh HD")
}

// MARK: - Uninstaller

struct InstalledApp: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let name: String
    let bundleID: String?
    let version: String
    let url: URL
    let byteCount: Int64
    let lastUsed: Date?
    let isSystem: Bool
    let executableName: String?
    let iconPath: String
}

enum LeftoverKind: String, CaseIterable, Hashable, Sendable {
    case applicationSupport
    case caches
    case preferences
    case savedState
    case logs
    case containers
    case other

    var title: String {
        switch self {
        case .applicationSupport: return "应用支持文件"
        case .caches: return "缓存"
        case .preferences: return "偏好设置"
        case .savedState: return "窗口状态"
        case .logs: return "日志"
        case .containers: return "容器"
        case .other: return "其他残留"
        }
    }
}

struct LeftoverItem: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let name: String
    let url: URL
    let byteCount: Int64
    let kind: LeftoverKind
    var isSelected: Bool
}

// MARK: - Large files

enum LargeFileKind: String, CaseIterable, Hashable, Sendable, Identifiable {
    case video
    case image
    case archive
    case document
    case diskImage
    case audio
    case code
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video: return "视频"
        case .image: return "图片"
        case .archive: return "压缩包"
        case .document: return "文档"
        case .diskImage: return "磁盘映像"
        case .audio: return "音频"
        case .code: return "开发文件"
        case .other: return "其他"
        }
    }

    var symbol: String {
        switch self {
        case .video: return "film.fill"
        case .image: return "photo.fill"
        case .archive: return "doc.zipper"
        case .document: return "doc.text.fill"
        case .diskImage: return "externaldrive.fill"
        case .audio: return "waveform"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .other: return "doc.fill"
        }
    }
}

struct LargeFile: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let url: URL
    let byteCount: Int64
    let modifiedAt: Date
    let kind: LargeFileKind
    var isSelected: Bool

    var name: String { url.lastPathComponent }
}

// MARK: - Space lens

struct SpaceNode: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let name: String
    let url: URL
    let byteCount: Int64
    let isDirectory: Bool
    let childCount: Int
    let children: [SpaceNode]

    var isEmpty: Bool { byteCount == 0 }
}

// MARK: - Clean history

struct CleanHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    let date: Date
    let freedBytes: Int64
    let itemCount: Int
}
