import Foundation

/// Thin adapter around the official Aptabase Swift SDK. Session handling, batching,
/// rate limiting and retries are all owned by the SDK; this file only forwards the
/// app's events and properties to it.
final class AptabaseAnalyticsProvider: AnalyticsProvider {
    static let shared = AptabaseAnalyticsProvider()
    static let defaultAppKey = "A-US-4062145019"

    private init() {
        let environment = ProcessInfo.processInfo.environment
        let appKey = environment["TIDYMAC_ANALYTICS_APPKEY"] ?? Self.defaultAppKey
        let debug = environment["TIDYMAC_ANALYTICS_DEBUG"] == "1"
        let options = InitOptions(trackingMode: debug ? .asDebug : .asRelease)
        Aptabase.shared.initialize(appKey: appKey, with: options)
    }

    func track(event: String, properties: [String: AnalyticsValue]) {
        var props: [String: Value] = [:]
        for (key, value) in properties {
            switch value {
            case .string(let text): props[key] = text
            case .int(let number): props[key] = Int(number)
            case .double(let number): props[key] = number
            }
        }
        Aptabase.shared.trackEvent(event, with: props)
    }

    func flush(timeout: TimeInterval) {
        // The SDK flushes from its own background actors; wait on a detached task so
        // blocking the main thread during termination cannot deadlock it.
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await Aptabase.shared.flush()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + max(0.2, timeout))
    }
}
