public enum Health: Int, Comparable, Sendable {
    case good, warn, bad

    public static func < (lhs: Health, rhs: Health) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum MemoryPressure: Sendable, Equatable {
    case normal, warn, critical

    /// `kern.memorystatus_vm_pressure_level`: 1 normal, 2 warn, 4 critical.
    public init(sysctlLevel: Int32) {
        switch sysctlLevel {
        case 4...: self = .critical
        case 2...: self = .warn
        default: self = .normal
        }
    }
}

public enum HealthEvaluator {
    public static let gigabyte: Int64 = 1_000_000_000

    public static func ram(_ pressure: MemoryPressure) -> Health {
        switch pressure {
        case .normal: .good
        case .warn: .warn
        case .critical: .bad
        }
    }

    public static func disk(free: Int64, total: Int64) -> Health {
        if free < 10 * gigabyte { return .bad }
        if free < 30 * gigabyte || Double(free) < Double(total) * 0.2 { return .warn }
        return .good
    }
}
