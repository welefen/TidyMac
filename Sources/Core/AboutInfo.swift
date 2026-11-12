import Foundation
import Darwin
import AppKit
import SystemConfiguration

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
            uptimeSeconds: ProcessInfo.processInfo.systemUptime
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
        uptimeSeconds: 3 * 86_400 + 4 * 3_600 + 12 * 60
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
