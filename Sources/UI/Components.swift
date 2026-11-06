import SwiftUI
import AppKit

// MARK: - Buttons


struct SoftButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13.5, weight: .semibold))
            .foregroundStyle(Theme.tint(tone))
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 7 : 10)
            .background(Capsule(style: .continuous).fill(Theme.softGradient(tone)))
            .overlay(Capsule(style: .continuous)
                .strokeBorder(Theme.tint(tone).opacity(0.28), lineWidth: 1))
            .shadow(color: Theme.tint(tone).opacity(configuration.isPressed ? 0.04 : 0.10),
                    radius: compact ? 6 : 10, x: 0, y: compact ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12.5 : 14, weight: .semibold))
            .foregroundStyle(Theme.textOnAccent)
            .padding(.horizontal, compact ? 14 : 22)
            .padding(.vertical, compact ? 8 : 11)
            .background(Capsule(style: .continuous).fill(Theme.gradient(tone)))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            .shadow(color: Theme.tint(tone).opacity(configuration.isPressed ? 0.15 : 0.30),
                    radius: compact ? 8 : 14, x: 0, y: compact ? 3 : 6)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13.5, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 7 : 10)
            .background(Capsule(style: .continuous).fill(Theme.cardElevated))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.strokeStrong, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tone: AccentTone = .mint

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.tint(tone))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.tint(tone).opacity(configuration.isPressed ? 0.16 : 0.0001))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct CircleIconButtonStyle: ButtonStyle {
    var size: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.cardElevated))
            .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var size: CGFloat = 220
    var tone: AccentTone = .mint
    var showsGlow = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, min(1, progress))))
                .stroke(Theme.angular(tone),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: showsGlow ? Theme.tint(tone).opacity(0.45) : .clear,
                        radius: showsGlow ? 18 : 0)
                .animation(.easeInOut(duration: 0.45), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Icons / badges

struct ToneIcon: View {
    let symbol: String
    var tone: AccentTone = .mint
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(Theme.softGradient(tone))
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .strokeBorder(Theme.tint(tone).opacity(0.18), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Theme.tint(tone))
        }
        .frame(width: size, height: size)
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
        case .safe: return Theme.mint
        case .caution: return Theme.orange
        case .risky: return Theme.red
        }
    }

    private var symbol: String {
        switch safety {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .risky: return "exclamationmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: compact ? 8 : 9, weight: .bold))
            if !compact {
                Text(L(label)).font(.system(size: 10.5, weight: .semibold))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 2 : 4)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.18), lineWidth: 0.5))
    }
}

struct TagBadge: View {
    let text: String
    var tone: AccentTone = .mint
    var filled = false

    var body: some View {
        Text(L(text))
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(filled ? Theme.textOnAccent : Theme.tint(tone))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(filled ? AnyShapeStyle(Theme.gradient(tone))
                                      : AnyShapeStyle(Theme.tint(tone).opacity(0.12)))
            )
    }
}

struct SelectionCheck: View {
    var isOn: Bool
    var isPartial = false
    var tone: AccentTone = .mint
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isOn || isPartial
                      ? AnyShapeStyle(Theme.gradient(tone))
                      : AnyShapeStyle(Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isOn || isPartial ? Color.clear : Theme.strokeStrong, lineWidth: 1.3)
                )
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.52, weight: .bold))
                    .foregroundStyle(Theme.textOnAccent)
            } else if isPartial {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.textOnAccent)
                    .frame(width: size * 0.42, height: 2)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: isOn)
        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: isPartial)
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
            VStack(alignment: .leading, spacing: 5) {
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            if let count {
                Text(Format.itemCount(count))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            if let subtitle {
                Text(L(subtitle))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder = "搜索"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            TextField(L(placeholder), text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.field))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

struct FilterPill: View {
    let title: String
    var isSelected: Bool
    var tone: AccentTone = .mint
    /// A softer selected state: tinted fill + tinted text instead of a saturated
    /// gradient. Used by low-density controls such as the appearance picker.
    var softSelection = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L(title))
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected
                                 ? (softSelection ? Theme.tint(tone) : Theme.textOnAccent)
                                 : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected
                              ? (softSelection
                                 ? AnyShapeStyle(Theme.tint(tone).opacity(0.13))
                                 : AnyShapeStyle(Theme.gradient(tone)))
                              : AnyShapeStyle(Theme.cardElevated))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isSelected
                                      ? (softSelection ? Theme.tint(tone).opacity(0.30) : Color.clear)
                                      : Theme.stroke,
                                      lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct StorageBar: View {
    var usedFraction: Double
    var tone: AccentTone = .mint
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.storageTrack)
                Capsule()
                    .fill(Theme.gradient(tone))
                    .frame(width: max(4, proxy.size.width * min(1, max(0, usedFraction))))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Rows / tiles

struct StatTile: View {
    let title: String
    let value: String
    var unit: String? = nil
    let symbol: String
    let tone: AccentTone
    var caption: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ToneIcon(symbol: symbol, tone: tone, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(L(title))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(L(value))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    if let unit {
                        Text(L(unit))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                if let caption {
                    Text(L(caption))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .qyPanel(padding: 15)
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
                .font(.system(size: 12, weight: .medium, design: mono ? .monospaced : .default))
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
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.mint.opacity(0.08))
                    .frame(width: 84, height: 84)
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.mint)
            }
            VStack(spacing: 5) {
                Text(L(title))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L(message))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            if let actionTitle, let action {
                Button(L(actionTitle), action: action)
                    .buttonStyle(PrimaryButtonStyle(tone: .mint, compact: true))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.4

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, Theme.shimmerHighlight, .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * 0.65)
                        .offset(x: phase * proxy.size.width)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Cards / hover

struct HoverLiftModifier: ViewModifier {
    @State private var hovering = false
    var scale: CGFloat = 1.012

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(hovering ? Theme.strokeStrong : Color.clear, lineWidth: 1)
            )
            .onHover { hovering = $0 }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
    }
}

extension View {
    func hoverLift(scale: CGFloat = 1.012) -> some View {
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
