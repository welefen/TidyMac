import SwiftUI
import AppKit

// MARK: - Sorting

enum AppSortOption: String, CaseIterable, Identifiable {
    case size
    case name
    case lastUsed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .size: return "按大小"
        case .name: return "按名称"
        case .lastUsed: return "按最近使用"
        }
    }

    var symbol: String {
        switch self {
        case .size: return "arrow.up.arrow.down"
        case .name: return "textformat.abc"
        case .lastUsed: return "clock"
        }
    }
}

// MARK: - Leftover styling

extension LeftoverKind {
    var tone: AccentTone { .mint }

    var symbol: String {
        switch self {
        case .applicationSupport: return "folder"
        case .caches: return "shippingbox"
        case .preferences: return "slider.horizontal.3"
        case .savedState: return "macwindow"
        case .logs: return "doc.text"
        case .containers: return "cube"
        case .backgroundItem: return "gearshape.2"
        case .other: return "archivebox"
        }
    }
}

/// "刚刚" for very recent timestamps, otherwise a short localized relative date.
func relativeUsageText(_ date: Date?) -> String {
    guard let date else { return "从未使用" }
    let delta = Date().timeIntervalSince(date)
    if delta >= 0 && delta < 60 { return L("刚刚") }
    return Format.relativeDate(date)
}

/// Deterministic accent used for demo apps that have no bundled icon on disk.
func appAccentTone(for name: String) -> AccentTone {
    .mint
}

// MARK: - App icon / glyph

struct AppGlyphView: View {
    let app: InstalledApp
    var size: CGFloat = 44

    var body: some View {
        if FileManager.default.fileExists(atPath: app.url.path) {
            AppIconView(path: app.url.path, size: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Theme.field)
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
                Text(String(app.name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Buttons

struct DangerButtonStyle: ButtonStyle {
    var tone: AccentTone = .red
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(Theme.negative)
            .padding(.horizontal, compact ? 12 : 16)
            .frame(height: compact ? 28 : 34)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(configuration.isPressed ? Theme.subtleFill : Theme.cardElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.negative.opacity(0.35), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Rows

struct AppListRow: View {
    let app: InstalledApp
    var isSelected: Bool
    var isRunning: Bool
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                AppGlyphView(app: app, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L(app.name))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("v\(app.version)")
                        if app.isSystem {
                            HStack(spacing: 2) {
                                Image(systemName: "lock")
                                    .font(.system(size: 8))
                                Text(L("系统"))
                                    .font(.system(size: 10))
                            }
                            .foregroundStyle(Theme.textTertiary)
                        }
                        if isRunning {
                            Text(L("运行中"))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.caution)
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Format.bytes(app.byteCount))
                        .font(Theme.monoFont(11.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    Text(relativeUsageText(app.lastUsed))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall + 2, style: .continuous)
                    .fill(isSelected ? Theme.cardElevated : (hovering ? Theme.subtleFill : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall + 2, style: .continuous)
                    .strokeBorder(isSelected ? Theme.strokeStrong : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct AppListSkeletonRow: View {
    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.cardElevated)
                    .frame(width: 118, height: 9)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.cardElevated.opacity(0.65))
                    .frame(width: 72, height: 8)
            }
            Spacer(minLength: 6)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.cardElevated.opacity(0.8))
                .frame(width: 46, height: 9)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .shimmering()
    }
}

struct LeftoverRowView: View {
    let item: LeftoverItem
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SelectionCheck(isOn: item.isSelected, size: 17)
                ToneIcon(symbol: item.kind.symbol, tone: item.kind.tone, size: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(item.name))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(HomePaths.relativePath(item.url))
                        .font(Theme.monoFont(9.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Text(Format.bytes(item.byteCount))
                    .font(Theme.monoFont(11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(item.isSelected ? Theme.textSecondary : Theme.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(hovering ? Theme.subtleFill : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Small pieces

struct MiniMetric: View {
    let title: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L(title))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Text(L(value))
                .font(mono ? Theme.monoFont(12.5, weight: .medium)
                           : .system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 26)
            .padding(.horizontal, 12)
    }
}

struct RunningAppWarning: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.caution)
            VStack(alignment: .leading, spacing: 1) {
                Text(L("应用当前正在运行"))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.caution)
                Text(L("建议先退出应用后再卸载，以释放被占用的文件"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.caution)
                .frame(width: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

struct UninstallResultBanner: View {
    let report: CleanReport
    let appName: String
    var dismiss: () -> Void

    private var hasFailure: Bool { !report.failures.isEmpty }

    private var message: String {
        if hasFailure {
            let reason = report.failures.first?.reason ?? "权限不足"
            return L("已移除 \(report.removedCount) 项，释放 \(Format.bytes(report.freedBytes))。\(reason) · 可尝试将应用手动拖入废纸篓")
        }
        return L("移除 \(report.removedCount) 项，共释放 \(Format.bytes(report.freedBytes))。")
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: hasFailure ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(hasFailure ? Theme.caution : Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(hasFailure ? "部分项目未能移除" : L("已卸载 \(appName)"))
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
