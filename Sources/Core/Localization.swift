import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return LocalizedText.tr("跟随系统")
        case .chinese: return "简体中文"
        case .english: return "English"
        }
    }

    /// The value written to AppleLanguages when the user overrides the system language.
    var appleLanguage: String? {
        switch self {
        case .system: return nil
        case .chinese: return "zh-Hans"
        case .english: return "en"
        }
    }
}

enum LocalizedText {
    static var isEnglish: Bool {
        Bundle.main.path(forResource: "en", ofType: "lproj") != nil
            && Bundle.main.preferredLocalizations.first?.hasPrefix("en") == true
    }

    static func tr(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        if localized != key { return localized }
        guard isEnglish else { return key }
        return translatePattern(key)
    }

    static func tr(_ format: String, _ arguments: CVarArg...) -> String {
        let localized = NSLocalizedString(format, comment: "")
        let resolved = localized == format ? fallbackFormat(format) : localized
        return String(format: resolved, arguments: arguments)
    }

    /// Converts the handful of format templates used by Format helpers when a
    /// .strings entry is missing.
    private static func fallbackFormat(_ format: String) -> String {
        switch format {
        case "%d 项": return "%d items"
        case "%.1f 秒": return "%.1f s"
        case "%d 分 %d 秒": return "%d min %d s"
        case "%d 秒": return "%d s"
        case "%d 分钟": return "%d min"
        default: return format
        }
    }

    private struct PatternRule {
        let pattern: String
        let template: String
    }

    private static let patternRules: [PatternRule] = [
        .init(pattern: "^共 (\\d+) 项 · 耗时 (.+) · 默认只选择安全项目$",
              template: "$1 items · $2 · Safe items selected by default"),
        .init(pattern: "^共 (\\d+) 项 · 耗时 (.+)$", template: "$1 items · $2"),
        .init(pattern: "^共 (\\d+) 项$", template: "$1 items"),
        .init(pattern: "^共 (\\d+) 个匹配文件$", template: "$1 matching files"),
        .init(pattern: "^共 (\\d+) 个项目$", template: "$1 items"),
        .init(pattern: "^共 (\\d+) 个子项目$", template: "$1 subitems"),
        .init(pattern: "^共 (\\d+) 个文件$", template: "$1 files"),
        .init(pattern: "^共 (.+) · 已用 (.+)$", template: "$1 total · $2 used"),
        .init(pattern: "^共 (.+)$", template: "$1 total"),
        .init(pattern: "^(.+) 可用$", template: "$1 available"),
        .init(pattern: "^已用 (.+)$", template: "$1 used"),
        .init(pattern: "^已选 (\\d+) 项 · (.+)$", template: "Selected $1 items · $2"),
        .init(pattern: "^已选 (\\d+) 项$", template: "Selected $1 items"),
        .init(pattern: "^发现 1 项$", template: "1 item found"),
        .init(pattern: "^共 1 项$", template: "1 item"),
        .init(pattern: "^1 项可清理$", template: "1 item to clean"),
        .init(pattern: "^1 项需注意$", template: "1 item needs attention"),
        .init(pattern: "^已选 1 项$", template: "Selected 1 item"),
        .init(pattern: "^1 项$", template: "1 item"),
        .init(pattern: "^1 项待清理$", template: "1 selected"),
        .init(pattern: "^1 个匹配文件$", template: "1 matching file"),
        .init(pattern: "^1 个项目$", template: "1 item"),
        .init(pattern: "^1 个子项目$", template: "1 subitem"),
        .init(pattern: "^1 个文件$", template: "1 file"),
        .init(pattern: "^1 个文件未能清理$", template: "1 file couldn't be cleaned"),
        .init(pattern: "^(\\d+) 项可清理$", template: "$1 items to clean"),
        .init(pattern: "^(\\d+) 项需注意$", template: "$1 items need attention"),
        .init(pattern: "^(\\d+) 项待清理$", template: "$1 selected"),
        .init(pattern: "^(\\d+) 个匹配文件$", template: "$1 matching files"),
        .init(pattern: "^最近 (\\d+) 条记录$", template: "Last $1 records"),
        .init(pattern: "^(\\d+) 类 · (\\d+) 项$", template: "$1 categories · $2 items"),
        .init(pattern: "^(\\d+) 个文件未能清理$", template: "$1 files couldn't be cleaned"),
        .init(pattern: "^版本 (.+)$", template: "Version $1"),
        .init(pattern: "^已加载 (\\d+) 个应用$", template: "$1 apps loaded"),
        .init(pattern: "^释放 (.+)$", template: "$1 freed"),
        .init(pattern: "^已清理 (\\d+) 项$", template: "$1 items cleaned"),
        .init(pattern: "^已移除 (\\d+) 项，释放 (.+)。$", template: "Removed $1 items, freed $2."),
        .init(pattern: "^移除 (\\d+) 项，共释放 (.+)。$", template: "Removed $1 items, freed $2 total."),
        .init(pattern: "^(\\d+) 个文件 · 释放 (.+)，可随时从废纸篓恢复。$", template: "$1 files · $2 freed. Restore from the Trash anytime."),
        .init(pattern: "^成功 (\\d+) 个，释放 (.+)。(.+)$", template: "Moved $1 files · $2 freed. $3"),
        .init(pattern: "^已移入废纸篓 (\\d+) 项，释放 (.+)$", template: "Moved $1 items to Trash · $2 freed"),
        .init(pattern: "^完成，移入废纸篓 (\\d+) 项，(\\d+) 项失败$", template: "Done — $1 moved to Trash, $2 failed"),
        .init(pattern: "^正在移到废纸篓… (\\d+)/(\\d+)$", template: "Moving to Trash… $1/$2"),
        .init(pattern: "^正在扫描 (.+)…$", template: "Scanning $1…"),
        .init(pattern: "^正在扫描(.+)…$", template: "Scanning $1…"),
        .init(pattern: "^正在分析 (.+)…$", template: "Analyzing $1…"),
        .init(pattern: "^正在清理 (.+)…$", template: "Cleaning $1…"),
        .init(pattern: "^正在卸载 (.+)…$", template: "Uninstalling $1…"),
        .init(pattern: "^正在扫描…已检查 (\\d+) 项$", template: "Scanning… $1 items checked"),
        .init(pattern: "^已扫描 (.+)$", template: "Scanned $1"),
        .init(pattern: "^已扫描(.+)$", template: "Scanned $1"),
        .init(pattern: "^发现 (\\d+) 项$", template: "$1 items found"),
        .init(pattern: "^正在检查 (.+) 的残留文件…$", template: "Checking leftovers for $1…"),
        .init(pattern: "^已卸载 (.+)$", template: "$1 uninstalled"),
        .init(pattern: "^(\\d+) 项$", template: "$1 items"),
        .init(pattern: "^(\\d+) 个$", template: "$1 items"),
        .init(pattern: "^(\\d+) 次$", template: "$1 times"),
        .init(pattern: "^(\\d+) 天$", template: "$1 days"),
        .init(pattern: "^(\\d+) 个子项目$", template: "$1 subitems"),
        .init(pattern: "^(\\d+) 个项目$", template: "$1 items"),
        .init(pattern: "^(\\d+) 个文件$", template: "$1 files"),
        .init(pattern: "^(.+) 项关联文件（(.+)）$", template: "$1 leftover files ($2)"),
        .init(pattern: "^已移除 (\\d+) 项，释放 (.+)。(.+) · 可尝试将应用手动拖入废纸篓$", template: "Removed $1 items, freed $2. $3 · Try dragging the app to the Trash manually"),
        .init(pattern: "^将移除应用及 (\\d+) 项残留$", template: "The app and $1 leftovers will be removed"),
        .init(pattern: "^含 (\\d+) 项重要项目$", template: "Includes $1 important items"),
        .init(pattern: "^清理 (.+)$", template: "Clean $1"),
        .init(pattern: "^全选当前列表中的 (\\d+) 个文件$", template: "Select all $1 files in this list"),
        .init(pattern: "^(\\d+) 项残留$", template: "$1 leftovers"),
        .init(pattern: "^正在读取应用… (\\d+)/(\\d+)$", template: "Reading apps… $1/$2"),
        .init(pattern: "^正在检查残留文件… (\\d+)/(\\d+)$", template: "Checking leftovers… $1/$2"),
        .init(pattern: "^正在删除残留文件… (\\d+)/(\\d+)$", template: "Removing leftovers… $1/$2"),
        .init(pattern: "^正在分析…已检查 (\\d+) 项$", template: "Analyzing… $1 items checked"),
        .init(pattern: "^分析完成，共 (.+)$", template: "Analysis complete · $1"),
        .init(pattern: "^扫描完成，找到 (\\d+) 个大文件$", template: "Scan complete · $1 large files found"),
        .init(pattern: "^扫描已取消，返回 (\\d+) 个大文件$", template: "Scan cancelled · $1 large files"),
        .init(pattern: "^目录不存在：(.+)$", template: "Folder not found: $1"),
        .init(pattern: "^无法读取目录：(.+)$", template: "Can't read folder: $1"),
        .init(pattern: "^正在检查 (.+) 的残留文件…$", template: "Checking leftovers for $1…"),
        .init(pattern: "^找到 (\\d+) 项残留，共 (.+)$", template: "$1 leftovers · $2"),
        .init(pattern: "^删除失败：(.+)$", template: "Delete failed: $1"),
        .init(pattern: "^包含 (\\d+) 个项目，清空后将无法恢复$", template: "Contains $1 items; emptying cannot be undone"),
        .init(pattern: "^包含 (\\d+) 个应用缓存项目，可安全重建$", template: "Contains $1 app cache items; safe to rebuild"),
        .init(pattern: "^包含 (\\d+) 个项目$", template: "Contains $1 items"),
        .init(pattern: "^共 (\\d+) 个附件文件，邮件正文与邮箱数据不受影响，附件可按需重新下载$", template: "$1 attachment files; mail content and mailbox data are unaffected, and attachments can be re-downloaded"),
        .init(pattern: "^(.+) · 最后备份 (.+) · 删除后需要重新备份$", template: "$1 · Last backup $2 · Back up again after deleting"),
        .init(pattern: "^(.+) 的备份，删除后需要重新备份$", template: "Backup of $1; back up again after deleting"),
        .init(pattern: "^已扫描 (\\d+) 项$", template: "$1 items scanned"),
        .init(pattern: "^正在扫描…已检查 (\\d+) 项$", template: "Scanning… $1 items checked")
    ]

    private static func translatePattern(_ input: String) -> String {
        let range = NSRange(input.startIndex..., in: input)
        for rule in patternRules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            if regex.firstMatch(in: input, range: range) != nil {
                return regex.stringByReplacingMatches(in: input, range: range, withTemplate: rule.template)
            }
        }
        return input
    }
}

/// Short aliases used throughout the app. Chinese source strings double as the
/// localization keys; the English Localizable.strings provides the translation.
func L(_ key: String) -> String { LocalizedText.tr(key) }
func L(_ format: String, _ arguments: CVarArg...) -> String {
    LocalizedText.tr(format, arguments)
}
