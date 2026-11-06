import Foundation
import AppKit
import CryptoKit

struct UpdateManifest: Decodable {
    let version: String
    let downloadURL: String
    let sha256: String
    let releaseNotes: String?
}

enum UpdatePhase: Equatable {
    case idle
    case checking
    case upToDate
    case available(String)
    case downloading(String)
    case ready(String)
    case installing(String)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .ready, .installing: return true
        default: return false
        }
    }
}

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    static let defaultFeedURL = URL(string: "https://api.github.com/repos/welefen/TidyMac/contents/updates/latest.json?ref=main")!
    static let fallbackFeedURL = URL(string: "https://raw.githubusercontent.com/welefen/TidyMac/main/updates/latest.json")!

    @Published private(set) var phase: UpdatePhase = .idle
    @Published private(set) var currentVersion: String = {
        if let override = ProcessInfo.processInfo.environment["TIDYMAC_CURRENT_VERSION"], !override.isEmpty {
            return override
        }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    private let settings = AppSettings.shared
    private static var didStartOnLaunch = false

    private static func debug(_ message: String) {
        guard ProcessInfo.processInfo.environment["TIDYMAC_UPDATE_DEBUG"] == "1" else { return }
        let line = "[\(Date())] \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/tidymac-update-debug.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private var feedURL: URL {
        if let raw = ProcessInfo.processInfo.environment["TIDYMAC_UPDATE_FEED"],
           let url = URL(string: raw) {
            return url
        }
        return Self.defaultFeedURL
    }

    var statusText: String {
        switch phase {
        case .idle:
            return L("尚未检查更新")
        case .checking:
            return L("正在检查更新…")
        case .upToDate:
            return L("已是最新版本")
        case .available(let version):
            return L("发现新版本 %@", version)
        case .downloading(let version):
            return L("正在下载 v%@…", version)
        case .ready(let version):
            return L("v%@ 已下载，可以安装", version)
        case .installing(let version):
            return L("正在安装 v%@ 并重新启动…", version)
        case .failed(let message):
            return message
        }
    }

    func startOnLaunch(isDemo: Bool) async {
        Self.debug("startOnLaunch demo=\(isDemo) autoCheck=\(settings.autoCheckUpdates)")
        guard !isDemo, !Self.didStartOnLaunch else { return }
        Self.didStartOnLaunch = true
        guard settings.autoCheckUpdates else { Self.debug("autoCheck disabled"); return }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        Self.debug("starting automatic check")
        guard phase == .idle else { return }
        await check(manual: false)
    }

    func check(manual: Bool) async {
        if case .checking = phase { return }
        if case .downloading = phase { return }
        if case .installing = phase { return }

        Self.debug("check manual=\(manual) feed=\(feedURL.absoluteString)")
        if manual {
            phase = .checking
        }
        do {
            let manifest = try await fetchManifest()
            Self.debug("manifest version=\(manifest.version) current=\(currentVersion)")
            guard Self.isVersion(manifest.version, newerThan: currentVersion) else {
                Self.debug("up to date")
                phase = .upToDate
                return
            }
            phase = .available(manifest.version)
            await downloadAndPrepare(manifest)
        } catch {
            let message = error.localizedDescription
            Self.debug("check failed: \(message)")
            phase = .failed(L("检查更新失败：%@", message))
        }
    }

    func installDownloadedUpdate() {
        guard case .ready(let version) = phase, let staged = stagedAppURL else { return }
        installAndRelaunch(staged: staged, version: version)
    }

    // MARK: - Feed

    private func fetchManifest() async throws -> UpdateManifest {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let token = ProcessInfo.processInfo.environment["TIDYMAC_UPDATE_TOKEN"], !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/vnd.github.raw", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw UpdateError.feedUnavailable
            }
            return try JSONDecoder().decode(UpdateManifest.self, from: data)
        } catch {
            // API rate limits and CDN hiccups: fall back to the public raw file.
            var fallback = URLRequest(url: Self.fallbackFeedURL)
            fallback.timeoutInterval = 15
            fallback.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: fallback)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw UpdateError.feedUnavailable
            }
            return try JSONDecoder().decode(UpdateManifest.self, from: data)
        }
    }

    // MARK: - Download

    private var stagedAppURL: URL?

    private func downloadAndPrepare(_ manifest: UpdateManifest) async {
        Self.debug("downloadAndPrepare \(manifest.version) \(manifest.downloadURL)")
        phase = .downloading(manifest.version)
        do {
            guard let downloadURL = URL(string: manifest.downloadURL) else {
                throw UpdateError.invalidDownloadURL
            }
            guard downloadURL.scheme == "https" || downloadURL.scheme == "http" else {
                throw UpdateError.invalidDownloadURL
            }

            let work = FileManager.default.temporaryDirectory
                .appendingPathComponent("TidyMacUpdate-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let archive = work.appendingPathComponent("update.zip")

            var request = URLRequest(url: downloadURL)
            request.timeoutInterval = 120
            if let token = ProcessInfo.processInfo.environment["TIDYMAC_UPDATE_TOKEN"], !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (temporaryFile, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw UpdateError.downloadFailed
            }
            try FileManager.default.moveItem(at: temporaryFile, to: archive)

            let expected = manifest.sha256.lowercased()
            let actual = try Self.sha256(of: archive)
            guard !expected.isEmpty, actual == expected else {
                throw UpdateError.checksumMismatch
            }

            let extracted = work.appendingPathComponent("extracted", isDirectory: true)
            try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
            try Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path])

            guard let app = Self.findAppBundle(in: extracted) else {
                throw UpdateError.appBundleMissing
            }
            guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
                  let identifier = info["CFBundleIdentifier"] as? String,
                  identifier == "com.tidymac.clean" else {
                throw UpdateError.invalidBundle
            }
            let stagedVersion = info["CFBundleShortVersionString"] as? String ?? ""
            guard stagedVersion == manifest.version else {
                throw UpdateError.versionMismatch
            }

            stagedAppURL = app
            phase = .ready(manifest.version)

            if settings.autoInstallUpdates {
                phase = .installing(manifest.version)
                try? await Task.sleep(nanoseconds: 600_000_000)
                installAndRelaunch(staged: app, version: manifest.version)
            }
        } catch {
            phase = .failed(L("下载更新失败：%@", error.localizedDescription))
        }
    }

    // MARK: - Install

    private func installAndRelaunch(staged: URL, version: String) {
        let target = Bundle.main.bundleURL
        let parent = target.deletingLastPathComponent()
        guard target.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: parent.path) else {
            phase = .failed(L("无法写入应用目录，请将 TidyMac 安装到「应用程序」后重试"))
            return
        }

        do {
            let script = FileManager.default.temporaryDirectory
                .appendingPathComponent("tidymac-update-\(UUID().uuidString).sh")
            let content = """
            #!/bin/sh
            pid="$1"
            target="$2"
            staged="$3"
            while kill -0 "$pid" 2> /dev/null; do
                sleep 0.3
            done
            backup="${target}.backup.$$"
            if [ -e "$target" ]; then
                mv "$target" "$backup" || exit 1
            fi
            if /usr/bin/ditto "$staged" "$target"; then
                rm -rf "$backup"
                /usr/bin/xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
                /usr/bin/open -n "$target"
                exit 0
            else
                rm -rf "$target"
                if [ -e "$backup" ]; then mv "$backup" "$target"; fi
                exit 1
            fi
            """
            try content.write(to: script, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [script.path, "\(ProcessInfo.processInfo.processIdentifier)", target.path, staged.path]
            try process.run()

            phase = .installing(version)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApp.terminate(nil)
            }
        } catch {
            phase = .failed(L("安装更新失败：%@", error.localizedDescription))
        }
    }

    // MARK: - Helpers

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.toolFailed((tool as NSString).lastPathComponent)
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func findAppBundle(in directory: URL) -> URL? {
        let direct = directory.appendingPathComponent("TidyMac.app")
        if FileManager.default.fileExists(atPath: direct.appendingPathComponent("Contents/Info.plist").path) {
            return direct
        }
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        for case let url as URL in enumerator where url.pathExtension == "app" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path) {
                return url
            }
        }
        return nil
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }
}

enum UpdateError: LocalizedError {
    case feedUnavailable
    case invalidManifest
    case invalidDownloadURL
    case downloadFailed
    case checksumMismatch
    case appBundleMissing
    case invalidBundle
    case versionMismatch
    case toolFailed(String)

    var errorDescription: String? {
        switch self {
        case .feedUnavailable:
            return L("无法访问更新源。GitHub 仓库需要是公开仓库，或无法连接网络。")
        case .invalidManifest:
            return L("更新清单格式无效")
        case .invalidDownloadURL:
            return L("更新下载地址无效")
        case .downloadFailed:
            return L("安装包下载失败")
        case .checksumMismatch:
            return L("安装包校验失败，已中止更新")
        case .appBundleMissing:
            return L("安装包中未找到 TidyMac.app")
        case .invalidBundle:
            return L("安装包不是有效的 TidyMac 应用")
        case .versionMismatch:
            return L("安装包版本与更新清单不一致")
        case .toolFailed(let tool):
            return L("解压安装包失败：%@", tool)
        }
    }
}
