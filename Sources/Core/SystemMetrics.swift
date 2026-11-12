import Foundation
import Darwin

// MARK: - Models

enum MemoryPressureLevel: String, Sendable, Equatable {
    case normal
    case warning
    case critical

    var title: String {
        switch self {
        case .normal: return L("内存压力正常")
        case .warning: return L("内存压力偏高")
        case .critical: return L("内存压力严重")
        }
    }
}

struct AppProcessUsage: Identifiable, Equatable, Sendable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let cpuFraction: Double
    let memoryBytes: Int64
}

struct AppUsage: Identifiable, Equatable, Sendable {
    var id: String { bundlePath }
    let name: String
    let bundlePath: String
    let cpuFraction: Double
    let memoryBytes: Int64
    let processes: [AppProcessUsage]

    var processCount: Int { processes.count }
}

struct SystemLoadSnapshot: Equatable, Sendable {
    let cpuFraction: Double
    let coreCount: Int
    let memoryUsedBytes: Int64
    let memoryTotalBytes: Int64
    let memoryPressure: MemoryPressureLevel
    let swapUsedBytes: Int64
    let appUsages: [AppUsage]
    let readableProcessCount: Int
    let sampledAt: Date
}

// MARK: - Monitor

/// Samples CPU, memory and per-app usage using Mach and libproc APIs.
/// All work happens on a utility queue; published values are delivered on main.
final class SystemLoadMonitor: ObservableObject {
    @Published private(set) var snapshot: SystemLoadSnapshot?
    @Published private(set) var isSampling = false

    private let queue = DispatchQueue(label: "com.tidymac.systemload", qos: .utility)
    private var timer: DispatchSourceTimer?
    private let interval: TimeInterval = 2

    private var previousHostCPU: host_cpu_load_info_data_t?
    private var previousPidCPU: [Int32: UInt64] = [:]
    private var previousSampleNanos: UInt64 = 0
    private var nameCache: [String: String] = [:]
    private let timebaseNumer: Double
    private let timebaseDenom: Double
    private var isDemo = false

    init() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        timebaseNumer = Double(timebase.numer)
        timebaseDenom = Double(timebase.denom)
    }

    func start(isDemo: Bool) {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            self.isDemo = isDemo
            self.previousHostCPU = nil
            self.previousPidCPU = [:]
            self.previousSampleNanos = 0

            if isDemo {
                let demo = self.makeDemoSnapshot()
                DispatchQueue.main.async {
                    self.snapshot = demo
                    self.isSampling = true
                }
                return
            }

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: self.interval, leeway: .milliseconds(250))
            timer.setEventHandler { [weak self] in
                self?.sample()
            }
            self.timer = timer
            timer.resume()
            DispatchQueue.main.async { self.isSampling = true }
        }
    }

    /// Requests an immediate sample (used after terminating an app).
    func refreshNow() {
        queue.async { [weak self] in
            guard let self, self.timer != nil else { return }
            self.sample()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.previousHostCPU = nil
            self.previousPidCPU = [:]
            self.previousSampleNanos = 0
            DispatchQueue.main.async { self.isSampling = false }
        }
    }

    // MARK: Sampling

    private func sample() {
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = previousSampleNanos == 0
            ? 0
            : Double(now - previousSampleNanos) / 1_000_000_000

        let cpu = sampleHostCPU()
        let memory = sampleMemory()
        let apps = sampleApps(elapsed: elapsed)

        previousSampleNanos = now

        let snapshot = SystemLoadSnapshot(
            cpuFraction: cpu.fraction,
            coreCount: ProcessInfo.processInfo.activeProcessorCount,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            memoryPressure: memory.pressure,
            swapUsedBytes: memory.swapUsed,
            appUsages: apps.usages,
            readableProcessCount: apps.readable,
            sampledAt: Date()
        )

        DispatchQueue.main.async { [weak self] in
            self?.snapshot = snapshot
        }
    }

    private func sampleHostCPU() -> (fraction: Double, perCore: [Double]) {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, []) }

        defer { previousHostCPU = info }
        guard let prev = previousHostCPU else { return (0, []) }

        let user = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + system + nice + idle
        guard total > 0 else { return (0, []) }
        return ((user + system + nice) / total, [])
    }

    private func sampleMemory() -> (used: Int64, total: Int64,
                                    pressure: MemoryPressureLevel, swapUsed: Int64) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = Int64(pageSize)
        let total = Int64(ProcessInfo.processInfo.physicalMemory)

        var used: Int64 = 0
        if kr == KERN_SUCCESS {
            used = (Int64(stats.active_count)
                    + Int64(stats.wire_count)
                    + Int64(stats.compressor_page_count)) * page
            used = min(max(used, 0), total)
        }

        var pressureLevel: Int32 = 1
        var pressureSize = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel,
                        &pressureSize, nil, 0) != 0 {
            pressureLevel = 1
        }
        let pressure: MemoryPressureLevel
        switch pressureLevel {
        case 2: pressure = .warning
        case 4: pressure = .critical
        default: pressure = .normal
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        var swapUsed: Int64 = 0
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            swapUsed = Int64(swap.xsu_used)
        }

        return (used, total, pressure, swapUsed)
    }

    private struct AggregatedProcess {
        var name: String
        var cpu: Double = 0
        var memory: Int64 = 0
    }

    private func sampleApps(elapsed: Double) -> (usages: [AppUsage], readable: Int) {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return ([], 0) }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let got = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard got > 0 else { return ([], 0) }

        var aggregated: [String: AggregatedProcess] = [:]
        var children: [String: [AppProcessUsage]] = [:]
        var nextCPU: [Int32: UInt64] = [:]
        var readable = 0

        var pathBuffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        var nameBuffer = [CChar](repeating: 0, count: 256)

        for index in 0..<Int(got) {
            let pid = pids[index]
            guard pid > 0 else { continue }

            pathBuffer.withUnsafeMutableBufferPointer { buffer in
                _ = proc_pidpath(pid, buffer.baseAddress, UInt32(buffer.count))
            }
            guard let executable = String(cString: pathBuffer, encoding: .utf8),
                  let bundlePath = Self.appBundlePath(in: executable) else { continue }

            var info = rusage_info_v4()
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { ptr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, ptr)
                }
            }
            guard kr == 0 else { continue }
            readable += 1

            let cpuUnits = info.ri_user_time &+ info.ri_system_time
            nextCPU[pid] = cpuUnits

            var fraction = 0.0
            if let previous = previousPidCPU[pid], elapsed > 0 {
                let delta = Double(cpuUnits &- previous)
                let seconds = delta * timebaseNumer / timebaseDenom / 1_000_000_000
                fraction = max(0, seconds / elapsed)
            }

            nameBuffer.withUnsafeMutableBufferPointer { buffer in
                _ = proc_name(pid, buffer.baseAddress, UInt32(buffer.count))
            }
            let processName = String(cString: nameBuffer, encoding: .utf8) ?? "PID \(pid)"

            if aggregated[bundlePath] == nil {
                aggregated[bundlePath] = AggregatedProcess(name: displayName(for: bundlePath))
            }
            aggregated[bundlePath]?.cpu += fraction
            aggregated[bundlePath]?.memory += Int64(info.ri_phys_footprint)
            children[bundlePath, default: []].append(
                AppProcessUsage(pid: pid, name: processName,
                                cpuFraction: fraction,
                                memoryBytes: Int64(info.ri_phys_footprint))
            )
        }

        previousPidCPU = nextCPU

        var usages: [AppUsage] = []
        usages.reserveCapacity(aggregated.count)
        for (bundlePath, value) in aggregated {
            let memory = value.memory
            let cpu = value.cpu
            guard memory >= 512 * 1024 || cpu >= 0.001 else { continue }
            let processes = (children[bundlePath] ?? []).sorted {
                if $0.cpuFraction == $1.cpuFraction { return $0.memoryBytes > $1.memoryBytes }
                return $0.cpuFraction > $1.cpuFraction
            }
            usages.append(
                AppUsage(name: value.name, bundlePath: bundlePath,
                         cpuFraction: cpu, memoryBytes: memory, processes: processes)
            )
        }
        usages.sort { $0.memoryBytes > $1.memoryBytes }
        return (usages, readable)
    }

    // MARK: Helpers

    private static func appBundlePath(in executable: String) -> String? {
        let components = executable.split(separator: "/", omittingEmptySubsequences: true)
        var path = ""
        for component in components {
            path += "/" + component
            if component.hasSuffix(".app") {
                return path
            }
        }
        return nil
    }

    private func displayName(for bundlePath: String) -> String {
        if let cached = nameCache[bundlePath] { return cached }
        let name: String
        if let bundle = Bundle(path: bundlePath) {
            name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? URL(fileURLWithPath: bundlePath).deletingPathExtension().lastPathComponent
        } else {
            name = URL(fileURLWithPath: bundlePath).deletingPathExtension().lastPathComponent
        }
        nameCache[bundlePath] = name
        return name
    }

    // MARK: Demo

    private func makeDemoSnapshot() -> SystemLoadSnapshot {
        func process(_ name: String, _ cpu: Double, _ memory: Int64, pid: Int32) -> AppProcessUsage {
            AppProcessUsage(pid: pid, name: name, cpuFraction: cpu, memoryBytes: memory)
        }
        let chromePath = "/Applications/Google Chrome.app"
        let xcodePath = "/Applications/Visual Studio Code.app"
        let safariPath = "/Applications/Safari.app"
        let dockerPath = "/Applications/Docker.app"
        let wechatPath = "/Applications/WeChat.app"
        let spotifyPath = "/Applications/ChatGPT.app"

        let apps: [AppUsage] = [
            AppUsage(name: "Google Chrome", bundlePath: chromePath,
                     cpuFraction: 0.184, memoryBytes: 2_310_000_000,
                     processes: [
                        process("Google Chrome", 0.121, 1_020_000_000, pid: 1201),
                        process("Google Chrome Helper (Renderer)", 0.046, 780_000_000, pid: 1202),
                        process("Google Chrome Helper (GPU)", 0.017, 510_000_000, pid: 1203)
                     ]),
            AppUsage(name: "Visual Studio Code", bundlePath: xcodePath,
                     cpuFraction: 0.072, memoryBytes: 1_820_000_000,
                     processes: [
                        process("Code Helper (Renderer)", 0.058, 1_120_000_000, pid: 1301),
                        process("SourceKitService", 0.014, 700_000_000, pid: 1302)
                     ]),
            AppUsage(name: "Docker", bundlePath: dockerPath,
                     cpuFraction: 0.041, memoryBytes: 1_240_000_000,
                     processes: [process("com.docker.backend", 0.041, 1_240_000_000, pid: 1401)]),
            AppUsage(name: "WeChat", bundlePath: wechatPath,
                     cpuFraction: 0.022, memoryBytes: 890_000_000,
                     processes: [process("WeChat", 0.022, 890_000_000, pid: 1501)]),
            AppUsage(name: "Safari", bundlePath: safariPath,
                     cpuFraction: 0.013, memoryBytes: 640_000_000,
                     processes: [
                        process("Safari", 0.009, 420_000_000, pid: 1601),
                        process("com.apple.WebKit.WebContent", 0.004, 220_000_000, pid: 1602)
                     ]),
            AppUsage(name: "ChatGPT", bundlePath: spotifyPath,
                     cpuFraction: 0.006, memoryBytes: 410_000_000,
                     processes: [process("ChatGPT", 0.006, 410_000_000, pid: 1701)])
        ]

        return SystemLoadSnapshot(
            cpuFraction: 0.183,
            coreCount: ProcessInfo.processInfo.activeProcessorCount,
            memoryUsedBytes: 9_400_000_000,
            memoryTotalBytes: 18_000_000_000,
            memoryPressure: .normal,
            swapUsedBytes: 0,
            appUsages: apps,
            readableProcessCount: 11,
            sampledAt: Date()
        )
    }
}
