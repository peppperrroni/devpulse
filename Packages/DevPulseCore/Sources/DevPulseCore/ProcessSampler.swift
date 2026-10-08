import Darwin
import Foundation

public struct ProcessEntry: Identifiable, Sendable, Equatable {
    public let pid: pid_t
    public var name: String
    public var path: String
    public var memory: UInt64
    public var cpuPercent: Double
    public var isApp: Bool

    public var id: pid_t { pid }
}

/// Lists the current user's processes. Holds the previous CPU times so the second
/// and later samples carry a CPU % (the first sample reports 0).
public final class ProcessSampler {
    private var previous: [pid_t: UInt64] = [:]   // pid → cpu ns
    private var previousAt: UInt64 = 0             // uptime ns
    private let timebase: (numer: UInt64, denom: UInt64)

    public init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebase = (UInt64(info.numer), UInt64(info.denom))
    }

    public func sample(apps: [pid_t: String]) -> [ProcessEntry] {
        let now = DispatchTime.now().uptimeNanoseconds
        let wall = previousAt == 0 ? 0 : now - previousAt
        var cpuNow: [pid_t: UInt64] = [:]
        var rows: [ProcessEntry] = []

        for pid in Self.userPIDs() {
            guard let usage = Self.rusage(pid) else { continue }
            // ri_user_time/ri_system_time are mach ticks on Apple Silicon.
            let cpu = (usage.ri_user_time + usage.ri_system_time) * timebase.numer / timebase.denom
            cpuNow[pid] = cpu
            var percent = 0.0
            if wall > 0, let before = previous[pid], cpu >= before {
                percent = Double(cpu - before) / Double(wall) * 100
            }
            let path = Self.path(pid)
            rows.append(ProcessEntry(
                pid: pid,
                name: apps[pid] ?? Self.displayName(pid: pid, path: path),
                path: path,
                memory: usage.ri_phys_footprint,
                cpuPercent: percent,
                isApp: apps[pid] != nil
            ))
        }
        previous = cpuNow
        previousAt = now
        return rows.sorted { $0.memory > $1.memory }
    }

    static func userPIDs() -> [pid_t] {
        let uid = UInt32(getuid())
        let needed = proc_listpids(UInt32(PROC_UID_ONLY), uid, nil, 0)
        guard needed > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(needed) / MemoryLayout<pid_t>.size + 32)
        let bytes = proc_listpids(UInt32(PROC_UID_ONLY), uid, &pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard bytes > 0 else { return [] }
        return pids.prefix(Int(bytes) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    static func rusage(_ pid: pid_t) -> rusage_info_v4? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info : nil
    }

    static func path(_ pid: pid_t) -> String {
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }

    static func displayName(pid: pid_t, path: String) -> String {
        let executable = path.isEmpty ? shortName(pid) : (path as NSString).lastPathComponent
        if executable == "java", let main = ProcessNaming.javaMainClass(arguments: ProcessNaming.arguments(pid: pid)) {
            return main
        }
        return executable
    }

    static func shortName(_ pid: pid_t) -> String {
        var buffer = [UInt8](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? String(decoding: buffer.prefix(Int(length)), as: UTF8.self) : "pid \(pid)"
    }
}

public enum ProcessNaming {
    /// Main class (last segment) or jar file name of a `java` command line.
    public static func javaMainClass(arguments: [String]) -> String? {
        var index = 1
        while index < arguments.count {
            let arg = arguments[index]
            if arg == "-jar", index + 1 < arguments.count {
                return (arguments[index + 1] as NSString).lastPathComponent
            }
            if ["-cp", "-classpath", "--class-path", "-p", "--module-path"].contains(arg) {
                index += 2
                continue
            }
            if !arg.hasPrefix("-"), isQualifiedClassName(arg) {
                return String(arg.split(separator: ".").last!)
            }
            index += 1
        }
        return nil
    }

    private static func isQualifiedClassName(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, let last = parts.last, last.first?.isUppercase == true else { return false }
        return parts.allSatisfy { part in
            guard let first = part.first, first.isLetter || first == "_" else { return false }
            return part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" }
        }
    }

    /// argv of a process via KERN_PROCARGS2; empty when not readable.
    public static func arguments(pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return [] }
        let argc = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        var i = MemoryLayout<Int32>.size
        while i < size, buffer[i] != 0 { i += 1 }   // executable path
        while i < size, buffer[i] == 0 { i += 1 }   // padding
        var args: [String] = []
        while args.count < Int(argc), i < size {
            let start = i
            while i < size, buffer[i] != 0 { i += 1 }
            args.append(String(decoding: buffer[start..<i], as: UTF8.self))
            i += 1
        }
        return args
    }
}
