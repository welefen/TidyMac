import Foundation
import Darwin
import AppKit
import SystemConfiguration
import IOKit.ps

/// Resolves the machine's public (egress) address through a lightweight public endpoint.
enum PublicIPService {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 6
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    static func fetch() async -> String? {
        if let address = await cloudflareTrace() { return address }
        return await ipify()
    }

    private static func cloudflareTrace() async -> String? {
        guard let url = URL(string: "https://1.1.1.1/cdn-cgi/trace") else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") where line.hasPrefix("ip=") {
            let value = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let valid = validated(value) { return valid }
        }
        return nil
    }

    private static func ipify() async -> String? {
        guard let url = URL(string: "https://api.ipify.org?format=json") else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(IPifyResponse.self, from: data) else { return nil }
        return validated(payload.ip)
    }

    private static func validated(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 45 else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF.:")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return trimmed
    }

    private struct IPifyResponse: Decodable {
        let ip: String
    }
}

/// Battery state and health details (nil on desktops without a battery).
struct BatteryInfo: Equatable, Sendable {
    var isPresent = false
    var chargePercent = 0
    var isCharging = false
    var isCharged = false
    var isPluggedIn = false
    var minutesToEmpty: Int?
    var minutesToFull: Int?
    var cycleCount: Int?
    var healthPercent: Int?
    var temperatureCelsius: Double?
}

/// Active system proxy configuration (if any).
struct ProxyInfo: Equatable, Sendable {
    var isEnabled = false
    var summary = ""
    var copyValue: String?
    var pacURL: String?
}

/// Static hardware, system and network facts shown on the About This Mac page.
struct AboutInfo: Equatable, Sendable {
    var modelIdentifier: String
    var chip: String
    var architecture: String
    var totalCores: Int
    var performanceCores: Int
    var efficiencyCores: Int
    var memoryBytes: Int64
    var disk: DiskInfo
    var displayName: String
    var displayResolution: String
    var screenCount: Int
    var osVersion: String
    var osBuild: String
    var hostName: String
    var primaryInterface: String
    var ipv4: String
    var macAddress: String
    var uptimeSeconds: TimeInterval
    var proxy: ProxyInfo = ProxyInfo()
    var battery: BatteryInfo = BatteryInfo()

    static let empty = AboutInfo(
        modelIdentifier: "—",
        chip: "—",
        architecture: "—",
        totalCores: 0,
        performanceCores: 0,
        efficiencyCores: 0,
        memoryBytes: 0,
        disk: .empty,
        displayName: "—",
        displayResolution: "—",
        screenCount: 0,
        osVersion: "—",
        osBuild: "—",
        hostName: "—",
        primaryInterface: "—",
        ipv4: "—",
        macAddress: "—",
        uptimeSeconds: 0
    )

    static func gather(isDemo: Bool) -> AboutInfo {
        if isDemo { return demo }
        return live()
    }

    // MARK: - Live

    private static func live() -> AboutInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = version.patchVersion > 0
            ? "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            : "\(version.majorVersion).\(version.minorVersion)"
        let build = sysctlString("kern.osversion") ?? "—"
        let network = networkInfo()
        let screen = NSScreen.main
        let scale = screen?.backingScaleFactor ?? 2
        let resolution: String
        if let frame = screen?.frame {
            resolution = "\(Int(frame.width * scale)) × \(Int(frame.height * scale))"
        } else {
            resolution = "—"
        }

        return AboutInfo(
            modelIdentifier: sysctlString("hw.model") ?? "—",
            chip: sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon",
            architecture: sysctlString("hw.machine") ?? "arm64",
            totalCores: sysctlInt("hw.ncpu") ?? ProcessInfo.processInfo.activeProcessorCount,
            performanceCores: sysctlInt("hw.perflevel0.logicalcpu") ?? 0,
            efficiencyCores: sysctlInt("hw.perflevel1.logicalcpu") ?? 0,
            memoryBytes: Int64(ProcessInfo.processInfo.physicalMemory),
            disk: DiskInfoProvider.current(),
            displayName: screen?.localizedName ?? "—",
            displayResolution: resolution,
            screenCount: NSScreen.screens.count,
            osVersion: osVersion,
            osBuild: build,
            hostName: ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: ""),
            primaryInterface: network.interface,
            ipv4: network.ipv4,
            macAddress: network.macAddress,
            uptimeSeconds: ProcessInfo.processInfo.systemUptime,
            proxy: proxyInfo(),
            battery: batteryInfo()
        )
    }

    // MARK: - Demo

    private static let demo = AboutInfo(
        modelIdentifier: "Mac15,6",
        chip: "Apple M3 Pro",
        architecture: "arm64",
        totalCores: 12,
        performanceCores: 6,
        efficiencyCores: 6,
        memoryBytes: 36 * 1_073_741_824,
        disk: DiskInfo(totalBytes: 994_000_000_000,
                       freeBytes: 195_800_000_000,
                       volumeName: "Macintosh HD"),
        displayName: "Built-in Liquid Retina XDR Display",
        displayResolution: "3024 × 1964",
        screenCount: 1,
        osVersion: "26.5",
        osBuild: "25F71",
        hostName: "demo-mac",
        primaryInterface: "en0",
        ipv4: "192.168.1.42",
        macAddress: "A4:83:E7:12:34:56",
        uptimeSeconds: 3 * 86_400 + 4 * 3_600 + 12 * 60,
        proxy: ProxyInfo(isEnabled: true,
                         summary: "HTTP/HTTPS · SOCKS",
                         copyValue: "127.0.0.1:7890 · 127.0.0.1:7891"),
        battery: BatteryInfo(isPresent: true,
                             chargePercent: 76,
                             isCharging: true,
                             isCharged: false,
                             isPluggedIn: true,
                             minutesToEmpty: nil,
                             minutesToFull: 73,
                             cycleCount: 128,
                             healthPercent: 92,
                             temperatureCelsius: 30.5)
    )

    // MARK: - Network

    private struct NetworkSnapshot {
        let interface: String
        let ipv4: String
        let macAddress: String
    }

    private static func networkInfo() -> NetworkSnapshot {
        var addresses: [String: String] = [:]
        var macs: [String: String] = [:]
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return NetworkSnapshot(interface: "—", ipv4: "—", macAddress: "—")
        }
        defer { freeifaddrs(pointer) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            let flags = Int32(current.pointee.ifa_flags)
            let name = String(cString: current.pointee.ifa_name)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp, !isLoopback, let addr = current.pointee.ifa_addr {
                switch Int32(addr.pointee.sa_family) {
                case AF_INET:
                    if addresses[name] == nil, let ip = ipv4String(addr) {
                        addresses[name] = ip
                    }
                case AF_LINK:
                    if macs[name] == nil, let mac = macString(addr) {
                        macs[name] = mac
                    }
                default:
                    break
                }
            }
            cursor = current.pointee.ifa_next
        }

        let preferred = ["en0", "en1", "bridge0"]
        let order = preferred + addresses.keys.filter { !preferred.contains($0) }.sorted()
        guard let iface = order.first(where: { addresses[$0] != nil }) else {
            return NetworkSnapshot(interface: "—", ipv4: "—", macAddress: "—")
        }
        let mac = macs[iface].flatMap { $0 == "00:00:00:00:00:00" ? nil : $0 }
            ?? hardwareAddress(for: iface)
            ?? "—"
        return NetworkSnapshot(interface: iface,
                               ipv4: addresses[iface] ?? "—",
                               macAddress: mac)
    }

    // MARK: - Battery

    private static func batteryInfo() -> BatteryInfo {
        var info = BatteryInfo()
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return info
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            let type = description[kIOPSTypeKey as String] as? String
            guard type == kIOPSInternalBatteryType as String else { continue }

            info.isPresent = true
            info.chargePercent = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            info.isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            info.isCharged = description[kIOPSIsChargedKey as String] as? Bool ?? false
            info.isPluggedIn = (description[kIOPSPowerSourceStateKey as String] as? String)
                == (kIOPSACPowerValue as String)
            let toEmpty = description[kIOPSTimeToEmptyKey as String] as? Int
            let toFull = description[kIOPSTimeToFullChargeKey as String] as? Int
            info.minutesToEmpty = (toEmpty ?? -1) > 0 ? toEmpty : nil
            info.minutesToFull = (toFull ?? -1) > 0 ? toFull : nil
            break
        }

        guard info.isPresent else { return info }

        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return info }
        defer { IOObjectRelease(service) }

        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()
        }

        info.cycleCount = property("CycleCount") as? Int
        if let design = property("DesignCapacity") as? Int, design > 0,
           let raw = property("AppleRawMaxCapacity") as? Int, raw > 0 {
            info.healthPercent = min(100, max(0, Int((Double(raw) / Double(design) * 100).rounded())))
        }
        if let temperature = property("Temperature") as? Int, temperature > 0 {
            info.temperatureCelsius = Double(temperature) / 100
        }
        return info
    }

    // MARK: - Proxy

    private static func proxyInfo() -> ProxyInfo {
        guard let dictionary = SCDynamicStoreCopyProxies(nil) as? [String: Any] else {
            return ProxyInfo()
        }

        func flag(_ key: CFString) -> Bool {
            guard let value = dictionary[key as String] else { return false }
            if let number = value as? NSNumber { return number.boolValue }
            if let bool = value as? Bool { return bool }
            return false
        }
        func text(_ key: CFString) -> String? {
            let value = dictionary[key as String] as? String
            return value?.isEmpty == false ? value : nil
        }
        func port(_ key: CFString) -> String? {
            guard let number = dictionary[key as String] as? NSNumber else { return nil }
            let value = number.intValue
            return value > 0 ? "\(value)" : nil
        }

        var groups: [(label: String, endpoint: String)] = []
        if flag(kSCPropNetProxiesHTTPEnable), let host = text(kSCPropNetProxiesHTTPProxy) {
            groups.append(("HTTP", host + (port(kSCPropNetProxiesHTTPPort).map { ":" + $0 } ?? "")))
        }
        if flag(kSCPropNetProxiesHTTPSEnable), let host = text(kSCPropNetProxiesHTTPSProxy) {
            groups.append(("HTTPS", host + (port(kSCPropNetProxiesHTTPSPort).map { ":" + $0 } ?? "")))
        }
        if flag(kSCPropNetProxiesSOCKSEnable), let host = text(kSCPropNetProxiesSOCKSProxy) {
            groups.append(("SOCKS", host + (port(kSCPropNetProxiesSOCKSPort).map { ":" + $0 } ?? "")))
        }

        var endpointOrder: [String] = []
        var labelsByEndpoint: [String: [String]] = [:]
        for group in groups {
            if labelsByEndpoint[group.endpoint] == nil { endpointOrder.append(group.endpoint) }
            labelsByEndpoint[group.endpoint, default: []].append(group.label)
        }

        let pacURL = flag(kSCPropNetProxiesProxyAutoConfigEnable)
            ? text(kSCPropNetProxiesProxyAutoConfigURLString)
            : nil
        let autoDiscovery = flag(kSCPropNetProxiesProxyAutoDiscoveryEnable)

        var parts = endpointOrder.map { endpoint in
            labelsByEndpoint[endpoint]!.joined(separator: "/")
        }
        if pacURL != nil { parts.append("PAC") }
        if autoDiscovery { parts.append(L("自动发现")) }

        let enabled = !parts.isEmpty
        let copyValue: String? = endpointOrder.isEmpty ? nil : endpointOrder.joined(separator: " · ")
        return ProxyInfo(isEnabled: enabled,
                         summary: parts.joined(separator: " · "),
                         copyValue: copyValue,
                         pacURL: pacURL)
    }

    private static func hardwareAddress(for interface: String) -> String? {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return nil }
        for entry in interfaces {
            guard let bsdName = SCNetworkInterfaceGetBSDName(entry) as String?,
                  bsdName == interface else { continue }
            return SCNetworkInterfaceGetHardwareAddressString(entry) as String?
        }
        return nil
    }

    private static func ipv4String(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(addr.pointee.sa_len)
        guard getnameinfo(addr, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
            return nil
        }
        return String(cString: host)
    }

    private static func macString(_ addr: UnsafeMutablePointer<sockaddr>) -> String? {
        let link = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_dl.self)
        guard link.pointee.sdl_alen == 6 else { return nil }
        let start = withUnsafePointer(to: link.pointee.sdl_data) {
            UnsafeRawPointer($0)
        }.advanced(by: Int(link.pointee.sdl_nlen))
        let bytes = UnsafeRawBufferPointer(start: start, count: 6)
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    // MARK: - sysctl

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let value = String(cString: buffer)
        return value.isEmpty ? nil : value
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
}
