import Darwin
import Foundation

public struct SystemSnapshot: Sendable, Equatable {
    public var ramUsed: UInt64
    public var ramTotal: UInt64
    public var pressure: MemoryPressure
    public var diskFree: Int64
    public var diskTotal: Int64

    public init(ramUsed: UInt64, ramTotal: UInt64, pressure: MemoryPressure, diskFree: Int64, diskTotal: Int64) {
        self.ramUsed = ramUsed
        self.ramTotal = ramTotal
        self.pressure = pressure
        self.diskFree = diskFree
        self.diskTotal = diskTotal
    }

    public var ramPercent: Int { Self.percent(Double(ramUsed), of: Double(ramTotal)) }
    public var diskUsedPercent: Int { Self.percent(Double(diskTotal - diskFree), of: Double(diskTotal)) }
    public var ramHealth: Health { HealthEvaluator.ram(pressure) }
    public var diskHealth: Health { HealthEvaluator.disk(free: diskFree, total: diskTotal) }
    public var overall: Health { max(ramHealth, diskHealth) }

    private static func percent(_ part: Double, of whole: Double) -> Int {
        guard whole > 0 else { return 0 }
        return min(100, max(0, Int((part / whole * 100).rounded())))
    }
}

public enum SystemSampler {
    public static func sample() -> SystemSnapshot {
        let disk = diskCapacity()
        return SystemSnapshot(
            ramUsed: ramUsedBytes(),
            ramTotal: ProcessInfo.processInfo.physicalMemory,
            pressure: MemoryPressure(sysctlLevel: pressureLevel()),
            diskFree: disk.free,
            diskTotal: disk.total
        )
    }

    static func pressureLevel() -> Int32 {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return 1 }
        return level
    }

    /// Activity Monitor's "Memory Used": app memory (internal − purgeable) + wired + compressed.
    static func ramUsedBytes() -> UInt64 {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let app = UInt64(stats.internal_page_count) - UInt64(min(stats.purgeable_count, stats.internal_page_count))
        let pages = app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * UInt64(pageSize)
    }

    static func diskCapacity() -> (free: Int64, total: Int64) {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return (0, 0) }
        return (values.volumeAvailableCapacityForImportantUsage ?? 0, Int64(values.volumeTotalCapacity ?? 0))
    }
}
