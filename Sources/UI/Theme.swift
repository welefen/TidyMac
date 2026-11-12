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
//
// One graphite ramp carries every surface, border and text role. A single deep
// green (taken from the app icon leaf) is the only accent; semantic colours are
// reserved for safety and destructive actions. No gradients, glows or colour
// washes in the chrome.

enum Theme {
    // Surfaces
    static let background = Color.adaptive(light: 0xF7F7F5, dark: 0x111110)
    static let backgroundLift = Color.adaptive(light: 0xFFFFFF, dark: 0x161615)
    static let sidebar = Color.adaptive(light: 0xF2F2EF, dark: 0x0D0D0C)
    static let panel = Color.adaptive(light: 0xFFFFFF, dark: 0x181817)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x191918)
    static let cardElevated = Color.adaptive(light: 0xFFFFFF, dark: 0x232321)
    static let cardHover = Color.adaptive(light: 0xF4F4F1, dark: 0x20201E)
    static let field = Color.adaptive(light: 0xEFEFEC, dark: 0x1C1C1A)

    // Lines
    static let stroke = Color.adaptive(light: 0x1B1B18, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08)
    static let strokeStrong = Color.adaptive(light: 0x1B1B18, dark: 0xFFFFFF, lightAlpha: 0.14, darkAlpha: 0.14)
    static let cardShadow = Color.adaptive(light: 0x1B1B18, dark: 0x000000, lightAlpha: 0.04, darkAlpha: 0)
    static let ringTrack = Color.adaptive(light: 0x1B1B18, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.08)
    static let storageTrack = Color.adaptive(light: 0x1B1B18, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.08)
    static let subtleFill = Color.adaptive(light: 0x1B1B18, dark: 0xFFFFFF, lightAlpha: 0.04, darkAlpha: 0.05)
    static let shimmerHighlight = Color.adaptive(light: 0x1B1B18, dark: 0xFFFFFF, lightAlpha: 0.03, darkAlpha: 0.04)

    // Text — three roles only
    static let textPrimary = Color.adaptive(light: 0x1B1B18, dark: 0xEDEDEA)
    static let textSecondary = Color.adaptive(light: 0x5C5C57, dark: 0xA6A6A0)
    static let textTertiary = Color.adaptive(light: 0x82827B, dark: 0x7F7F79)
    static let textOnAccent = Color.adaptive(light: 0xFFFFFF, dark: 0x0A1512)
    static let textOnMint = textOnAccent

    // Accent: the leaf green of the app icon.
    static let accent = Color.adaptive(light: 0x146B56, dark: 0x6FD3B2)
    static let accentHover = Color.adaptive(light: 0x0F5745, dark: 0x86E1C3)

    // Semantic
    static let positive = Color.adaptive(light: 0x1F7A5F, dark: 0x5CC9A7)
    static let caution = Color.adaptive(light: 0x8A621E, dark: 0xD8A25A)
    static let negative = Color.adaptive(light: 0xB4433A, dark: 0xE2796B)

    // Compatibility names for older call sites. All non-semantic tones resolve
    // to the one accent so no rainbow icons survive a missed call site.
    static let mint = accent
    static let blue = accent
    static let purple = accent
    static let pink = accent
    static let yellow = accent
    static let teal = accent
    static let orange = caution
    static let red = negative

    // Layout
    static let sidebarWidth: CGFloat = 248
    static let pagePadding: CGFloat = 32
    static let corner: CGFloat = 14
    static let cornerSmall: CGFloat = 8
    static let windowMinWidth: CGFloat = 1060
    static let windowMinHeight: CGFloat = 700

    static func tint(_ tone: AccentTone) -> Color {
        switch tone {
        case .orange: return caution
        case .red: return negative
        default: return accent
        }
    }

    static func secondaryTint(_ tone: AccentTone) -> Color {
        tint(tone)
    }

    /// Kept for call-site compatibility; the design no longer uses hue
    /// gradients, so these resolve to a single solid accent.
    static func gradient(_ tone: AccentTone) -> LinearGradient {
        LinearGradient(colors: [tint(tone), tint(tone)], startPoint: .top, endPoint: .bottom)
    }

    static func softGradient(_ tone: AccentTone) -> LinearGradient {
        LinearGradient(colors: [tint(tone).opacity(0.10), tint(tone).opacity(0.10)],
                       startPoint: .top, endPoint: .bottom)
    }

    static func angular(_ tone: AccentTone) -> AngularGradient {
        AngularGradient(colors: [tint(tone), tint(tone)], center: .center,
                        startAngle: .degrees(0), endAngle: .degrees(360))
    }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent], startPoint: .top, endPoint: .bottom)
    }

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, accent], startPoint: .top, endPoint: .bottom)
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [background, background], startPoint: .top, endPoint: .bottom)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [card, card], startPoint: .top, endPoint: .bottom)
    }

    // Type — SF Pro for the interface, SF Mono for figures and meta.
    static let titleFont = Font.system(size: 30, weight: .medium)
    static let sectionFont = Font.system(size: 15, weight: .medium)
    static let bodyFont = Font.system(size: 13, weight: .regular)
    static let labelFont = Font.system(size: 12, weight: .regular)
    static let wordmarkFont = Font.system(size: 17, weight: .semibold)
    static let numericFont = Font.system(size: 30, weight: .medium).monospacedDigit()

    static func figureFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
    }
}

// MARK: - Backgrounds

/// A plain page background. Kept as a type so the window shell can stay
/// unchanged while the old blurred colour washes are gone.
struct AuroraBackground: View {
    var body: some View {
        Theme.background
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
                    .shadow(color: Theme.cardShadow, radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
    }

    /// Deprecated: depth now comes from surface steps and hairlines.
    func qyGlow(_ color: Color, radius: CGFloat = 20, opacity: Double = 0.35, y: CGFloat = 8) -> some View {
        self
    }

    func qyHoverLift(_ isHovered: Bool, scale: CGFloat = 1.012) -> some View {
        self
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Fonts / text

extension Text {
    func qyPrimary() -> some View {
        self.foregroundStyle(Theme.textPrimary)
    }
}
