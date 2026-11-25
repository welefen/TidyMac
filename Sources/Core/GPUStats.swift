import Foundation
import IOKit

/// Whole-machine GPU readings exposed by the accelerator driver.
///
/// Apple Silicon reports these through the `IOAccelerator` registry entry; no
/// privileges are required. Values cover utilization and unified-memory use,
/// not power, clocks or temperature (those need a privileged sampler).
struct GPUMetrics: Equatable, Sendable {
    let utilizationFraction: Double
    let allocatedBytes: Int64
    let inUseBytes: Int64
    let coreCount: Int
    let model: String
}

enum GPUProbe {
    static func sample() -> GPUMetrics? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }

            guard let stats = registryProperty(entry, "PerformanceStatistics") as? [String: Any],
                  let utilization = utilizationFraction(from: stats) else { continue }

            let allocated = int64(stats["Alloc system memory"]) ?? 0
            let inUse = int64(stats["In use system memory"]) ?? 0
            let model = registryProperty(entry, "model") as? String ?? "GPU"
            let cores = int(registryProperty(entry, "gpu-core-count")) ?? 0

            return GPUMetrics(
                utilizationFraction: utilization,
                allocatedBytes: max(allocated, 0),
                inUseBytes: max(inUse, 0),
                coreCount: max(cores, 0),
                model: model
            )
        }

        return nil
    }

    private static func utilizationFraction(from stats: [String: Any]) -> Double? {
        for key in ["Device Utilization %", "GPU Activity(%)", "GPU Activity %"] {
            if let value = number(stats[key]) {
                return min(max(value / 100, 0), 1)
            }
        }
        return nil
    }

    private static func registryProperty(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(
            entry,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        if let int = value as? Int64 { return int }
        if let int = value as? Int { return Int64(int) }
        if let double = value as? Double { return Int64(double) }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let int = value as? Int { return int }
        return nil
    }
}
