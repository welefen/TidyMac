import Foundation

enum Format {
    private static var appLocale: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return formatter
    }()

    /// "12.4 GB" style. Uses localized units and keeps one decimal place for GB+.
    static func bytes(_ value: Int64) -> String {
        guard value > 0 else { return "0 B" }
        if value < 1024 { return "\(value) B" }
        return byteFormatter.string(fromByteCount: value)
    }

    /// Short value split into number and unit for large display typography.
    static func bytesParts(_ value: Int64) -> (number: String, unit: String) {
        let text = bytes(value)
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        guard parts.count >= 2 else { return (text, "") }
        return (String(parts[0]), parts.dropFirst().joined(separator: " "))
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((min(1, max(0, fraction)) * 100).rounded()))%"
    }

    static func itemCount(_ count: Int) -> String {
        L("\(count) 项")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }()

    static func date(_ date: Date?) -> String {
        guard let date else { return L("从未") }
        return dateFormatter.string(from: date)
    }

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return L("从未") }
        return dateTimeFormatter.string(from: date)
    }

    static func relativeDate(_ date: Date?) -> String {
        guard let date else { return L("未知") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = appLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return L("不到 1 秒") }
        if seconds < 60 { return L("%.1f 秒", seconds) }
        let minutes = Int(seconds / 60)
        let remainder = Int(seconds.truncatingRemainder(dividingBy: 60))
        return L("%d 分 %d 秒", minutes, remainder)
    }

    static func compactDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return L("%d 秒", Int(seconds.rounded())) }
        return L("%d 分钟", Int((seconds / 60).rounded()))
    }
}
