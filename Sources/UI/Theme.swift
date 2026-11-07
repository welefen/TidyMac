import SwiftUI
import AppKit

// MARK: - Adaptive color helpers

extension Color {
    /// A color that follows the macOS appearance (light / dark).
    static func adaptive(light: UInt32,
                         dark: UInt32,
                         lightAlpha: Double = 1,
                         darkAlpha: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(srgbHex: isDark ? dark : light,
                           alpha: CGFloat(isDark ? darkAlpha : lightAlpha))
        })
    }

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

extension NSColor {
    convenience init(srgbHex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((srgbHex >> 16) & 0xFF) / 255,
                  green: CGFloat((srgbHex >> 8) & 0xFF) / 255,
                  blue: CGFloat(srgbHex & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - Design tokens

enum Theme {
    // Surfaces
    static let background = Color.adaptive(light: 0xF3F6FA, dark: 0x070A0F)
    static let backgroundLift = Color.adaptive(light: 0xFFFFFF, dark: 0x0A1019)
    static let sidebar = Color.adaptive(light: 0xEEF2F8, dark: 0x090D14)
    static let panel = Color.adaptive(light: 0xFFFFFF, dark: 0x101722)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x141C28)
    static let cardElevated = Color.adaptive(light: 0xFFFFFF, dark: 0x19222F)
    static let cardHover = Color.adaptive(light: 0xF4F8FD, dark: 0x1B2533)
    static let field = Color.adaptive(light: 0xF1F4F9, dark: 0x0E141D)

    // Lines
    static let stroke = Color.adaptive(light: 0x101828, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.07)
    static let strokeStrong = Color.adaptive(light: 0x101828, dark: 0xFFFFFF, lightAlpha: 0.15, darkAlpha: 0.13)
    static let cardShadow = Color.adaptive(light: 0x142033, dark: 0x000000, lightAlpha: 0.07, darkAlpha: 0)
    static let ringTrack = Color.adaptive(light: 0x0E1726, dark: 0xFFFFFF, lightAlpha: 0.09, darkAlpha: 0.06)
    static let storageTrack = Color.adaptive(light: 0x0E1726, dark: 0xFFFFFF, lightAlpha: 0.09, darkAlpha: 0.07)
    static let subtleFill = Color.adaptive(light: 0x0E1726, dark: 0xFFFFFF, lightAlpha: 0.045, darkAlpha: 0.05)
    static let shimmerHighlight = Color.adaptive(light: 0x0E1726, dark: 0xFFFFFF, lightAlpha: 0.045, darkAlpha: 0.09)

    // Text
    static let textPrimary = Color.adaptive(light: 0x171D27, dark: 0xF2F5FA)
    static let textSecondary = Color.adaptive(light: 0x5B6778, dark: 0x9BA8BA)
    static let textTertiary = Color.adaptive(light: 0x8793A4, dark: 0x68758A)
    static let textOnAccent = Color(hex: 0x06110E)
    /// Foreground for solid mint fills. White in light mode (matches the update
    /// badge reference); dark in dark mode, where mint is much brighter.
    static let textOnMint = Color.adaptive(light: 0xFFFFFF, dark: 0x06110E)

    // Tones
    static let mint = Color.adaptive(light: 0x0FAF8E, dark: 0x5CE8C4)
    static let blue = Color.adaptive(light: 0x1F7BE5, dark: 0x4BA3FF)
    static let purple = Color.adaptive(light: 0x7A5AF8, dark: 0xA78BFA)
    static let orange = Color.adaptive(light: 0xE0862A, dark: 0xFFB86B)
    static let pink = Color.adaptive(light: 0xE2558F, dark: 0xFF7AB8)
    static let yellow = Color.adaptive(light: 0xC99512, dark: 0xFFD86B)
    static let teal = Color.adaptive(light: 0x0E9FB5, dark: 0x4DD6E8)
    static let red = Color.adaptive(light: 0xE04B4B, dark: 0xFF6B6B)

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
        LinearGradient(colors: [tint(tone).opacity(0.20), secondaryTint(tone).opacity(0.07)],
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
        LinearGradient(colors: [mint, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [background, backgroundLift], startPoint: .top, endPoint: .bottom)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [
            Color.adaptive(light: 0xFFFFFF, dark: 0x16222F),
            Color.adaptive(light: 0xF4FBF8, dark: 0x0F1722),
            Color.adaptive(light: 0xEDF6FF, dark: 0x0B1119)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let titleFont = Font.system(size: 27, weight: .bold, design: .rounded)
    static let sectionFont = Font.system(size: 15, weight: .semibold)
    static let bodyFont = Font.system(size: 13, weight: .regular)
    static let numericFont = Font.system(size: 32, weight: .bold, design: .rounded).monospacedDigit()
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
                    .shadow(color: Theme.cardShadow, radius: 18, x: 0, y: 6)
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
