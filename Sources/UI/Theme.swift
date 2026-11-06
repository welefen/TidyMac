import SwiftUI

// MARK: - Design tokens

enum Theme {
    // Surfaces
    static let background = Color(hex: 0x070A0F)
    static let backgroundLift = Color(hex: 0x0A1019)
    static let sidebar = Color(hex: 0x090D14)
    static let panel = Color(hex: 0x101722)
    static let card = Color(hex: 0x141C28)
    static let cardElevated = Color(hex: 0x19222F)
    static let cardHover = Color(hex: 0x1B2533)
    static let field = Color(hex: 0x0E141D)

    // Lines
    static let stroke = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.13)

    // Text
    static let textPrimary = Color(hex: 0xF2F5FA)
    static let textSecondary = Color(hex: 0x9BA8BA)
    static let textTertiary = Color(hex: 0x68758A)
    static let textOnAccent = Color(hex: 0x06110E)

    // Tones
    static let mint = Color(hex: 0x5CE8C4)
    static let blue = Color(hex: 0x4BA3FF)
    static let purple = Color(hex: 0xA78BFA)
    static let orange = Color(hex: 0xFFB86B)
    static let pink = Color(hex: 0xFF7AB8)
    static let yellow = Color(hex: 0xFFD86B)
    static let teal = Color(hex: 0x4DD6E8)
    static let red = Color(hex: 0xFF6B6B)

    // Layout
    static let sidebarWidth: CGFloat = 238
    static let pagePadding: CGFloat = 34
    static let corner: CGFloat = 18
    static let cornerSmall: CGFloat = 12
    static let windowMinWidth: CGFloat = 1060
    static let windowMinHeight: CGFloat = 700

    static func tint(_ tone: AccentTone) -> Color {
        switch tone {
        case .mint: return mint
        case .blue: return blue
        case .purple: return purple
        case .orange: return orange
        case .pink: return pink
        case .yellow: return yellow
        case .teal: return teal
        case .red: return red
        }
    }

    static func secondaryTint(_ tone: AccentTone) -> Color {
        switch tone {
        case .mint: return blue
        case .blue: return purple
        case .purple: return pink
        case .orange: return yellow
        case .pink: return purple
        case .yellow: return orange
        case .teal: return mint
        case .red: return orange
        }
    }

    static func gradient(_ tone: AccentTone) -> LinearGradient {
        LinearGradient(colors: [tint(tone), secondaryTint(tone)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static func softGradient(_ tone: AccentTone) -> LinearGradient {
        LinearGradient(colors: [tint(tone).opacity(0.22), secondaryTint(tone).opacity(0.08)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static func angular(_ tone: AccentTone) -> AngularGradient {
        AngularGradient(colors: [tint(tone), secondaryTint(tone), tint(tone)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360))
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [mint, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x8AF5DC), Color(hex: 0x5CE8C4), Color(hex: 0x4BA3FF)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x070A0F), Color(hex: 0x0A1019)],
                       startPoint: .top, endPoint: .bottom)
    }

    static let titleFont = Font.system(size: 27, weight: .bold, design: .rounded)
    static let sectionFont = Font.system(size: 15, weight: .semibold)
    static let bodyFont = Font.system(size: 13, weight: .regular)
    static let numericFont = Font.system(size: 32, weight: .bold, design: .rounded).monospacedDigit()
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    init(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        let value = UInt32(text, radix: 16) ?? 0
        self.init(hex: value)
    }
}

// MARK: - Backgrounds

struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient
            Circle()
                .fill(Theme.mint.opacity(0.10))
                .frame(width: 560, height: 560)
                .blur(radius: 130)
                .offset(x: -420, y: -320)
            Circle()
                .fill(Theme.blue.opacity(0.10))
                .frame(width: 640, height: 640)
                .blur(radius: 150)
                .offset(x: 460, y: 320)
            Circle()
                .fill(Theme.purple.opacity(0.07))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: 320, y: -300)
        }
        .ignoresSafeArea()
    }
}

// MARK: - View modifiers

extension View {
    func qyPanel(padding: CGFloat = 20,
                 cornerRadius: CGFloat = Theme.corner,
                 fill: Color = Theme.card,
                 stroke: Color = Theme.stroke) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
    }

    func qyGlow(_ color: Color, radius: CGFloat = 20, opacity: Double = 0.35, y: CGFloat = 8) -> some View {
        shadow(color: color.opacity(opacity), radius: radius, x: 0, y: y)
    }

    func qyHoverLift(_ isHovered: Bool, scale: CGFloat = 1.012) -> some View {
        self
            .scaleEffect(isHovered ? scale : 1)
            .brightness(isHovered ? 0.02 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
    }
}

// MARK: - Fonts / text

extension Text {
    func qyPrimary() -> some View {
        self.foregroundStyle(Theme.textPrimary)
    }
}
