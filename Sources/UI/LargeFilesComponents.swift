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
    var tone: AccentTone { .mint }
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
                               size: 17)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.35)
            .help(isAllSelected ? "取消全选当前列表" : "全选当前列表")
            .accessibilityLabel(isAllSelected ? "取消全选当前列表" : "全选当前列表")

            Color.clear.frame(width: 26, height: 1)

            Text(L("名称"))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: toggleSort) {
                HStack(spacing: 3) {
                    Text(L("大小"))
                    Image(systemName: sortDescending ? "chevron.down" : "chevron.up")
                        .font(.system(size: 8, weight: .medium))
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 92, alignment: .trailing)

            Text(L("修改时间"))
                .frame(width: 96, alignment: .trailing)

            Color.clear.frame(width: 28, height: 1)
        }
        .font(.system(size: 10.5, weight: .medium))
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
        HStack(spacing: 11) {
            SelectionCheck(isOn: isSelected, size: 17)

            ToneIcon(symbol: file.kind.symbol, tone: file.kind.tone, size: 17)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(L(file.name))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(HomePaths.relativePath(file.url))
                    .font(Theme.monoFont(9.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(Format.bytes(file.byteCount))
                .font(Theme.monoFont(11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 92, alignment: .trailing)

            Text(Format.relativeDate(file.modifiedAt))
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .frame(width: 96, alignment: .trailing)

            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHovered ? Theme.field : Color.clear)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 28)
            .help("在 Finder 中显示")
            .opacity(isHovered || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(isSelected ? Theme.cardElevated : (isHovered ? Theme.cardHover : Color.clear))
                .padding(.horizontal, 5)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

// MARK: - Banner

struct LargeFilesResultBanner: View {
    let report: CleanReport
    var dismiss: () -> Void

    private var hasFailure: Bool { !report.failures.isEmpty }

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
            Image(systemName: hasFailure ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(hasFailure ? Theme.caution : Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(title))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L(message))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.field))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

// MARK: - States

struct LargeFilesSkeletonRow: View {
    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 17, height: 17)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 20, height: 17)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.cardElevated)
                    .frame(width: 180, height: 9)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.cardElevated.opacity(0.6))
                    .frame(width: 250, height: 8)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 60, height: 9)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
    }
}

struct LargeFilesScanningState: View {
    let progress: Double
    let status: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(L("正在扫描"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                Text(L(status))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text(Format.percent(progress))
                    .font(Theme.monoFont(11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            CapacityRuler(fraction: progress, height: 5)
            Text(L("正在扫描下载、文档、桌面、影片、图片与音乐目录…"))
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 460)
    }
}
