import SwiftUI
import AppKit

// MARK: - Filters

enum LargeFileSizeFilter: String, CaseIterable, Identifiable {
    case mb100
    case mb500
    case gb1
    case gb5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mb100: return "100MB"
        case .mb500: return "500MB"
        case .gb1: return "1GB"
        case .gb5: return "5GB"
        }
    }

    var bytes: Int64 {
        switch self {
        case .mb100: return 100_000_000
        case .mb500: return 500_000_000
        case .gb1: return 1_000_000_000
        case .gb5: return 5_000_000_000
        }
    }
}

enum LargeFileAgeFilter: String, CaseIterable, Identifiable {
    case all
    case d30
    case d90
    case y1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .d30: return "30 天前"
        case .d90: return "90 天前"
        case .y1: return "1 年前"
        }
    }

    var days: Int? {
        switch self {
        case .all: return nil
        case .d30: return 30
        case .d90: return 90
        case .y1: return 365
        }
    }
}

extension LargeFileKind {
    var tone: AccentTone {
        switch self {
        case .video: return .pink
        case .image: return .purple
        case .archive: return .orange
        case .document: return .blue
        case .diskImage: return .teal
        case .audio: return .yellow
        case .code: return .mint
        case .other: return .blue
        }
    }
}

// MARK: - Table header

struct LargeFilesTableHeader: View {
    var sortDescending: Bool
    var isAllSelected: Bool
    var isPartiallySelected: Bool
    var isEnabled: Bool
    var toggleSort: () -> Void
    var toggleAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleAll) {
                SelectionCheck(isOn: isAllSelected,
                               isPartial: isPartiallySelected,
                               tone: .mint,
                               size: 18)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.35)
            .help(isAllSelected ? "取消全选当前列表" : "全选当前列表")
            .accessibilityLabel(isAllSelected ? "取消全选当前列表" : "全选当前列表")
            Color.clear.frame(width: 34, height: 1)
            Text("名称")
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: toggleSort) {
                HStack(spacing: 3) {
                    Text("大小")
                    Image(systemName: sortDescending ? "chevron.down" : "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 92, alignment: .trailing)
            Text("修改时间")
                .frame(width: 96, alignment: .trailing)
            Color.clear.frame(width: 32, height: 1)
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Theme.textTertiary)
        .padding(.horizontal, 14)
        .frame(height: 34)
    }
}

// MARK: - File row

struct LargeFileRowView: View {
    let file: LargeFile
    let isSelected: Bool
    let isHovered: Bool
    var onToggle: () -> Void
    var onReveal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SelectionCheck(isOn: isSelected, tone: .mint, size: 19)

            ToneIcon(symbol: file.kind.symbol, tone: file.kind.tone, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(L(file.name))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(HomePaths.relativePath(file.url))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(Format.bytes(file.byteCount))
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Theme.mint : Theme.textSecondary)
                .frame(width: 92, alignment: .trailing)

            Text(Format.relativeDate(file.modifiedAt))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .frame(width: 96, alignment: .trailing)

            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.field))
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(width: 32)
            .help("在 Finder 中显示")
            .opacity(isHovered ? 1 : 0.55)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Theme.cardElevated
                      : (isHovered ? Theme.cardHover : Color.clear))
                .padding(.horizontal, 6)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(Theme.gradient(.mint))
                    .frame(width: 3, height: 26)
                    .padding(.leading, 5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

// MARK: - Banner

struct LargeFilesResultBanner: View {
    let report: CleanReport
    var dismiss: () -> Void

    private var hasFailure: Bool { !report.failures.isEmpty }
    private var tint: Color { hasFailure ? Theme.orange : Theme.mint }

    private var title: String {
        hasFailure ? "部分文件未能移入废纸篓" : "已移入废纸篓"
    }

    private var message: String {
        if hasFailure {
return L("成功 %d 个，释放 %@。%@", report.removedCount, Format.bytes(report.freedBytes), report.failures.first?.reason ?? L("权限不足"))
        }
        return L("\(report.removedCount) 个文件 · 释放 \(Format.bytes(report.freedBytes))，可随时从废纸篓恢复。")
    }

    var body: some View {
        HStack(spacing: 11) {
            ToneIcon(symbol: hasFailure ? "exclamationmark.triangle.fill" : "trash.fill",
                     tone: hasFailure ? .orange : .mint, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(title))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L(message))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.field))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - States

struct LargeFilesSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 19, height: 19)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.cardElevated)
                    .frame(width: 180, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.cardElevated.opacity(0.6))
                    .frame(width: 250, height: 8)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 60, height: 10)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .shimmering()
    }
}

struct LargeFilesScanningState: View {
    let progress: Double
    let status: String

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.mint)
                Text(L(status))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(Format.percent(progress))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mint)
            }
            StorageBar(usedFraction: progress, tone: .mint, height: 6)
            Text("正在扫描下载、文档、桌面、影片、图片与音乐目录…")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(20)
        .frame(maxWidth: 460)
    }
}
