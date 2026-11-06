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
    var tone: AccentTone {
        switch self {
        case .applicationSupport: return .orange
        case .caches: return .blue
        case .preferences: return .purple
        case .savedState: return .teal
        case .logs: return .yellow
        case .containers: return .pink
        case .other: return .mint
        }
    }

    var symbol: String {
        switch self {
        case .applicationSupport: return "folder.fill"
        case .caches: return "shippingbox.fill"
        case .preferences: return "slider.horizontal.3"
        case .savedState: return "macwindow"
        case .logs: return "doc.text.fill"
        case .containers: return "cube.fill"
        case .other: return "archivebox.fill"
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
    let palette: [AccentTone] = [.mint, .blue, .purple, .orange, .pink, .teal, .yellow, .red]
    guard !name.isEmpty else { return palette[0] }
    let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return palette[sum % palette.count]
}

// MARK: - App icon / glyph

struct AppGlyphView: View {
    let app: InstalledApp
    var size: CGFloat = 44

    var body: some View {
        let tone = appAccentTone(for: app.name)
        if FileManager.default.fileExists(atPath: app.url.path) {
            AppIconView(path: app.url.path, size: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(Theme.softGradient(tone))
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(Theme.tint(tone).opacity(0.24), lineWidth: 1)
                Text(String(app.name.prefix(1)))
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.tint(tone))
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
            .font(.system(size: compact ? 12.5 : 13.5, weight: .semibold))
            .foregroundStyle(Theme.tint(tone))
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 8 : 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.tint(tone).opacity(configuration.isPressed ? 0.26 : 0.13))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Theme.tint(tone).opacity(0.35), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
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
                AppGlyphView(app: app, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L(app.name))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text("v\(app.version)")
                        if app.isSystem {
                            HStack(spacing: 2) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7.5, weight: .bold))
                                Text("系统")
                                    .font(.system(size: 9.5, weight: .semibold))
                            }
                            .foregroundStyle(Theme.textTertiary)
                        }
                        if isRunning {
                            Text("运行中")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Theme.orange)
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Format.bytes(app.byteCount))
                        .font(.system(size: 11.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Theme.mint : Theme.textSecondary)
                    Text(relativeUsageText(app.lastUsed))
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? Theme.cardElevated
                          : (hovering ? Theme.card.opacity(0.75) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isSelected ? Theme.strokeStrong : Color.clear, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(Theme.gradient(.mint))
                        .frame(width: 3, height: 26)
                        .offset(x: -1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct AppListSkeletonRow: View {
    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.cardElevated)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.cardElevated)
                    .frame(width: 118, height: 10)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.cardElevated.opacity(0.65))
                    .frame(width: 72, height: 8)
            }
            Spacer(minLength: 6)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.cardElevated.opacity(0.8))
                .frame(width: 46, height: 10)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
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
                SelectionCheck(isOn: item.isSelected, tone: .mint, size: 18)
                ToneIcon(symbol: item.kind.symbol, tone: item.kind.tone, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(item.name))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(HomePaths.relativePath(item.url))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Text(Format.bytes(item.byteCount))
                    .font(.system(size: 11.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.isSelected ? Theme.textSecondary : Theme.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? Theme.cardHover : Color.clear)
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
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            Text(L(value))
                .font(.system(size: 12.5, weight: .semibold,
                              design: mono ? .monospaced : .rounded))
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("应用当前正在运行")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                Text("建议先退出应用后再卸载，以释放被占用的文件")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.orange.opacity(0.22), lineWidth: 1)
        )
    }
}

struct UninstallResultBanner: View {
    let report: CleanReport
    let appName: String
    var dismiss: () -> Void

    private var hasFailure: Bool { !report.failures.isEmpty }
    private var tint: Color { hasFailure ? Theme.orange : Theme.mint }

    private var message: String {
        if hasFailure {
            let reason = report.failures.first?.reason ?? "权限不足"
            return L("已移除 \(report.removedCount) 项，释放 \(Format.bytes(report.freedBytes))。\(reason) · 可尝试将应用手动拖入废纸篓")
        }
        return L("移除 \(report.removedCount) 项，共释放 \(Format.bytes(report.freedBytes))。")
    }

    var body: some View {
        HStack(spacing: 11) {
            ToneIcon(symbol: hasFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                     tone: hasFailure ? .orange : .mint, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(hasFailure ? "部分项目未能移除" : L("已卸载 \(appName)"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L(message))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
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
        .padding(.vertical, 9)
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
