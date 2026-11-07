import Foundation

// MARK: - Values

/// A property value that can be attached to an analytics event. Aptabase accepts
/// strings and numbers; booleans are reported as 0/1 integers.
enum AnalyticsValue: Equatable, Sendable {
    case string(String)
    case int(Int64)
    case double(Double)
}

// MARK: - Events

/// Stable event names reported to Aptabase. Aptabase does not require events to
/// be pre-registered, but names should stay lowercase snake_case and never be
/// renamed after shipping.
enum AnalyticsEvent: String, CaseIterable, Sendable {
    /// Application launch. Properties: language, appearance, initial_page.
    case appStart = "app_start"
    /// Application quit. Properties: duration_ms.
    case appEnd = "app_end"
    /// Opened one of the main pages. Properties: page.
    case pageView = "page_view"

    /// Smart scan started. Properties: trigger.
    case scanStart = "scan_start"
    /// Smart scan cancelled. Properties: progress_percent.
    case scanCancel = "scan_cancel"
    /// Smart scan finished. Properties: item_count, total_bytes, category_count, duration_ms.
    case scanComplete = "scan_complete"
    /// A scan result was added to the exclusion list. Properties: kind, path_count, item_bytes.
    case excludeItem = "exclude_item"

    /// Cleanup started. Properties: item_count, total_bytes, risky_count, move_to_trash.
    case cleanStart = "clean_start"
    /// Cleanup finished. Properties: removed_count, freed_bytes, failure_count, move_to_trash.
    case cleanComplete = "clean_complete"

    /// App uninstall started. Properties: leftover_count, total_bytes, move_to_trash.
    case uninstallStart = "uninstall_start"
    /// App uninstall finished. Properties: removed_count, freed_bytes, failure_count, move_to_trash.
    case uninstallComplete = "uninstall_complete"

    /// Large files scan finished. Properties: file_count, total_bytes.
    case largeFilesScan = "large_files_scan"
    /// Large files moved to the trash. Properties: file_count, freed_bytes, failure_count.
    case largeFilesClean = "large_files_clean"

    /// Space Lens analysis finished. Properties: child_count, bytes_scanned.
    case spaceLensScan = "space_lens_scan"
}

// MARK: - Provider

protocol AnalyticsProvider: AnyObject {
    func track(event: String, properties: [String: AnalyticsValue])
    /// Sends anything still queued, waiting at most `timeout` seconds.
    func flush(timeout: TimeInterval)
}

/// Chooses the reporting backend. Both languages currently use Aptabase through the
/// official Swift SDK; when the English build moves to another service, change only
/// this mapping.
enum AnalyticsProviderFactory {
    static func provider(for language: AppLanguage) -> AnalyticsProvider? {
        switch language {
        case .chinese, .english, .system:
            return AptabaseAnalyticsProvider.shared
        }
    }
}

// MARK: - Facade

/// Single entry point used by the rest of the app. Analytics are always on (except
/// in demo mode, so screenshots and development runs never pollute real data).
@MainActor
final class Analytics {
    static let shared = Analytics()

    private var provider: AnalyticsProvider?
    private var isDemoRun = false
    private var currentLanguage: AppLanguage = .system
    private let sessionStartedAt = Date()

    private init() {}

    var isEnabled: Bool { !isDemoRun }

    /// Called once at launch, after the app settings have been loaded.
    func configure(language: AppLanguage, isDemo: Bool) {
        isDemoRun = isDemo
        currentLanguage = language.effective
        refreshProvider()
    }

    func track(_ event: AnalyticsEvent, _ properties: [String: AnalyticsValue] = [:]) {
        guard isEnabled, let provider else { return }
        provider.track(event: event.rawValue, properties: properties)
    }

    /// Best-effort delivery of queued events; used before the app terminates.
    func flush(timeout: TimeInterval = 2) {
        guard isEnabled, let provider else { return }
        provider.flush(timeout: timeout)
    }

    var sessionDurationMilliseconds: Int64 {
        Int64(Date().timeIntervalSince(sessionStartedAt) * 1000)
    }

    private func refreshProvider() {
        if isEnabled {
            if provider == nil {
                provider = AnalyticsProviderFactory.provider(for: currentLanguage)
            }
        } else {
            provider = nil
        }
    }
}

// MARK: - Helpers

extension AppLanguage {
    /// The language that is actually displayed, with the system preference
    /// resolved. Unsupported system languages fall back to English.
    var effective: AppLanguage {
        switch self {
        case .system: return LocalizedText.isEnglish ? .english : .chinese
        default: return self
        }
    }

    var analyticsCode: String { effective.rawValue }
}
