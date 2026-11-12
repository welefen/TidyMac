import Foundation

enum SpeedTestSource: String, CaseIterable, Identifiable, Sendable {
    case cloudflare
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cloudflare: return "Cloudflare 快速"
        case .system: return "系统网络质量"
        }
    }
}

struct SpeedTestResult: Equatable, Sendable {
    var source: SpeedTestSource
    var latencyMs: Double?
    var downloadMbps: Double?
    var uploadMbps: Double?
}

enum SpeedTestFailure: LocalizedError {
    case cancelled
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return L("已取消")
        case .unavailable(let reason): return reason
        }
    }
}

enum SpeedTestRunner {
    // A deliberately small sample: enough to be indicative without burning much data.
    private static let downloadBytes = 10_000_000
    private static let uploadBytes = 4_000_000
    private static let latencySamples = 3

    private static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        // Cloudflare rejects the default URLSession/curl user agent on the speed endpoints.
        request.setValue("TidyMac/1.1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    static func cloudflare() async throws -> SpeedTestResult {
        let client = session()
        var latencyValues: [Double] = []

        // Warm up DNS/TLS so the measured latency does not include cold-start cost.
        if let warmup = URL(string: "https://speed.cloudflare.com/__down?bytes=0") {
            _ = try? await client.data(for: request(warmup))
        }

        for _ in 0..<latencySamples {
            try Task.checkCancellation()
            guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0") else { continue }
            let started = Date()
            let (_, response) = try await client.data(for: request(url))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            latencyValues.append(Date().timeIntervalSince(started) * 1_000)
        }

        let latency = median(latencyValues)

        try Task.checkCancellation()
        let downloadStart = Date()
        guard let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=\(downloadBytes)") else {
            throw SpeedTestFailure.unavailable(L("测速服务不可用"))
        }
        let (downloadData, downloadResponse) = try await client.data(for: request(downloadURL))
        guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200, !downloadData.isEmpty else {
            throw SpeedTestFailure.unavailable(L("下载测速失败"))
        }
        let downloadSeconds = max(Date().timeIntervalSince(downloadStart), 0.001)
        let downloadMbps = Double(downloadData.count) * 8 / downloadSeconds / 1_000_000

        try Task.checkCancellation()
        guard let uploadURL = URL(string: "https://speed.cloudflare.com/__up") else {
            throw SpeedTestFailure.unavailable(L("测速服务不可用"))
        }
        var uploadRequest = request(uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let uploadBody = Data(count: uploadBytes)
        let uploadStart = Date()
        let (_, uploadResponse) = try await client.upload(for: uploadRequest, from: uploadBody)
        guard let status = (uploadResponse as? HTTPURLResponse)?.statusCode, (200..<400).contains(status) else {
            throw SpeedTestFailure.unavailable(L("上传测速失败"))
        }
        let uploadSeconds = max(Date().timeIntervalSince(uploadStart), 0.001)
        let uploadMbps = Double(uploadBytes) * 8 / uploadSeconds / 1_000_000

        return SpeedTestResult(source: .cloudflare,
                               latencyMs: latency,
                               downloadMbps: downloadMbps,
                               uploadMbps: uploadMbps)
    }

    static func systemNetworkQuality() async throws -> SpeedTestResult {
        let handle = ProcessHandle()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SpeedTestResult, Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
                process.arguments = ["-c", "-s", "-M", "25"]
                let output = Pipe()
                let errors = Pipe()
                process.standardOutput = output
                process.standardError = errors
                handle.process = process
                process.terminationHandler = { finished in
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    guard finished.terminationStatus == 0, !data.isEmpty else {
                        continuation.resume(throwing: SpeedTestFailure.unavailable(L("系统网络质量测试失败")))
                        return
                    }
                    do {
                        let result = try parseNetworkQuality(data)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: SpeedTestFailure.unavailable(L("无法启动系统网络质量测试")))
                }
            }
        } onCancel: {
            handle.process?.terminate()
        }
    }

    private static func parseNetworkQuality(_ data: Data) throws -> SpeedTestResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpeedTestFailure.unavailable(L("无法解析系统测速结果"))
        }
        let latency = (json["base_rtt"] as? NSNumber)?.doubleValue
        let download = (json["dl_throughput"] as? NSNumber).map { $0.doubleValue * 8 / 1_000_000 }
        let upload = (json["ul_throughput"] as? NSNumber).map { $0.doubleValue * 8 / 1_000_000 }
        return SpeedTestResult(source: .system,
                               latencyMs: latency,
                               downloadMbps: download,
                               uploadMbps: upload)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

/// Holds the running process so cancellation can reach it without capturing mutable state.
private final class ProcessHandle: @unchecked Sendable {
    var process: Process?
}
