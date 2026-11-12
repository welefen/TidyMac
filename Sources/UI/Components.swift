import SwiftUI
import AppKit

// MARK: - Buttons
//
// Flat, one accent, 8pt corners. No capsule gradients, glows or springs.

struct PrimaryButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(Theme.textOnAccent)
            .padding(.horizontal, compact ? 12 : 16)
            .frame(height: compact ? 28 : 34)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.accent)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, compact ? 12 : 16)
            .frame(height: compact ? 28 : 34)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.cardElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.strokeStrong, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, compact ? 10 : 12)
            .frame(height: compact ? 26 : 30)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(configuration.isPressed ? Theme.subtleFill : Color.clear)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Theme.subtleFill : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct CircleIconButtonStyle: ButtonStyle {
    var size: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(configuration.isPressed ? Theme.subtleFill : Color.clear)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Capacity ruler (signature)

/// A 6pt byte ruler with a tick every 10%. Used under capacity figures and
/// storage summaries. This is the one place a figure gets a drawn measure.
struct CapacityRuler: View {
    var fraction: Double
    var height: CGFloat = 6
    var ticks: Int = 10

    private var clamped: CGFloat { CGFloat(min(1, max(0, fraction))) }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 2) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.storageTrack)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: max(2, proxy.size.width * clamped))
                }
                .frame(height: height)
                ZStack(alignment: .leading) {
                    ForEach(0...max(2, ticks), id: \.self) { index in
                        Rectangle()
                            .fill(Theme.textTertiary.opacity(0.45))
                            .frame(width: 1, height: 3)
                            .offset(x: max(0, min(proxy.size.width - 1,
                                                   proxy.size.width * CGFloat(index) / CGFloat(max(2, ticks)))))
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(height: height + 5)
        .accessibilityHidden(true)
    }
}

struct StorageBar: View {
    var usedFraction: Double
    var tone: AccentTone = .mint
    var height: CGFloat = 6

    var body: some View {
        CapacityRuler(fraction: usedFraction, height: height)
    }
}

// MARK: - Ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6
    var size: CGFloat = 220
    var tone: AccentTone = .mint
    var showsGlow = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(1, progress))))
                .stroke(Theme.accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: progress)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Icons / badges

/// A plain, single-weight glyph. No tile, no tint.
struct ToneIcon: View {
    let symbol: String
    var tone: AccentTone = .mint
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: min(18, max(13, size * 0.46)), weight: .regular))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct SafetyBadge: View {
    let safety: SafetyLevel
    var compact = false

    private var label: String {
        switch safety {
        case .safe: return "安全"
        case .caution: return "谨慎"
        case .risky: return "重要"
        }
    }

    private var color: Color {
        switch safety {
        case .safe: return Theme.textTertiary
        case .caution: return Theme.caution
        case .risky: return Theme.negative
        }
    }

    private var symbol: String {
        switch safety {
        case .safe: return "checkmark.shield"
        case .caution: return "exclamationmark.triangle"
        case .risky: return "exclamationmark.octagon"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .regular))
            if !compact {
                Text(L(label))
                    .font(.system(size: 11, weight: .regular))
            }
        }
        .foregroundStyle(color)
    }
}

struct TagBadge: View {
    let text: String
    var tone: AccentTone = .mint
    var filled = false

    var body: some View {
        Text(L(text))
            .font(Theme.monoFont(10.5, weight: .medium))
            .foregroundStyle(filled ? Theme.accent : Theme.textTertiary)
    }
}

struct SelectionCheck: View {
    var isOn: Bool
    var isPartial = false
    var tone: AccentTone = .mint
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isOn || isPartial ? Theme.textPrimary : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(isOn || isPartial ? Color.clear : Theme.strokeStrong, lineWidth: 1)
                )
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(Theme.background)
            } else if isPartial {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.background)
                    .frame(width: size * 0.42, height: 2)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.12), value: isOn)
        .animation(.easeOut(duration: 0.12), value: isPartial)
    }
}

// MARK: - Page / section chrome

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L(title))
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.textPrimary)
                Text(L(subtitle))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 16)
            trailing
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var count: Int? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(L(title))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(L(subtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if let count {
                Text(Format.itemCount(count))
                    .font(Theme.monoFont(11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder = "搜索"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
            TextField(L(placeholder), text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.field)
        )
    }
}

struct FilterPill: View {
    let title: String
    var isSelected: Bool
    var tone: AccentTone = .mint
    var softSelection = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L(title))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Theme.cardElevated : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Theme.strokeStrong : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Data figures

/// A stat is its number, its unit and its label. No icon, no card, no colour.
struct StatTile: View {
    let title: String
    let value: String
    var unit: String? = nil
    let symbol: String
    let tone: AccentTone
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(title))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(L(value))
                    .font(Theme.figureFont(24))
                    .foregroundStyle(Theme.textPrimary)
                if let unit {
                    Text(L(unit))
                        .font(Theme.monoFont(11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            if let caption {
                Text(L(caption))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

struct KeyValueRow: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        HStack {
            Text(L(label))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Text(L(value))
                .font(mono ? Theme.monoFont(12) : .system(size: 12, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
    }
}

// MARK: - Empty / loading

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Theme.textTertiary)
            }
            VStack(spacing: 6) {
                Text(L(title))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(L(message))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            if let actionTitle, let action {
                Button(L(actionTitle), action: action)
                    .buttonStyle(PrimaryButtonStyle(tone: .mint, compact: true))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// Loading placeholders stay static: no looping shimmer.
struct ShimmerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Hover

struct HoverLiftModifier: ViewModifier {
    @State private var hovering = false
    var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(hovering ? Theme.strokeStrong : Color.clear, lineWidth: 1)
            )
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1) -> some View {
        modifier(HoverLiftModifier(scale: scale))
    }
}

// MARK: - AppKit bridges

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

enum AppPermissionActions {
    static var applicationURL: URL { Bundle.main.bundleURL }

    static func revealApplicationInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([applicationURL])
    }
}

/// The real application icon, used anywhere the in-app brand mark is shown so
/// it always matches the Dock / Finder icon.
struct AppBrandIcon: View {
    var size: CGFloat = 40

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct AppIconView: View {
    let path: String
    var size: CGFloat = 44

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.5)
            )
    }
}

// MARK: - Formatting helpers for views

extension SafetyLevel {
    var tone: AccentTone {
        switch self {
        case .safe: return .mint
        case .caution: return .orange
        case .risky: return .red
        }
    }

    var symbol: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .risky: return "exclamationmark.octagon.fill"
        }
    }
}
