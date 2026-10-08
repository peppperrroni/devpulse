import Testing
@testable import DevPulseCore

struct HealthTests {
    let gb = HealthEvaluator.gigabyte

    @Test func pressureFromSysctlLevel() {
        #expect(MemoryPressure(sysctlLevel: 0) == .normal)
        #expect(MemoryPressure(sysctlLevel: 1) == .normal)
        #expect(MemoryPressure(sysctlLevel: 2) == .warn)
        #expect(MemoryPressure(sysctlLevel: 4) == .critical)
    }

    @Test func ramFollowsPressure() {
        #expect(HealthEvaluator.ram(.normal) == .good)
        #expect(HealthEvaluator.ram(.warn) == .warn)
        #expect(HealthEvaluator.ram(.critical) == .bad)
    }

    @Test func diskGoodAtExactBoundaries() {
        // exactly 20 % and exactly 30 GB free is still good
        #expect(HealthEvaluator.disk(free: 30 * gb, total: 150 * gb) == .good)
    }

    @Test func diskWarnBelowTwentyPercent() {
        #expect(HealthEvaluator.disk(free: 99 * gb, total: 500 * gb) == .warn)
    }

    @Test func diskWarnBelowThirtyGigabytes() {
        #expect(HealthEvaluator.disk(free: 30 * gb - 1, total: 100 * gb) == .warn)
    }

    @Test func diskBadBelowTenGigabytes() {
        #expect(HealthEvaluator.disk(free: 10 * gb - 1, total: 40 * gb) == .bad)
        #expect(HealthEvaluator.disk(free: 10 * gb, total: 40 * gb) == .warn)
    }

    @Test func healthOrdersBySeverity() {
        #expect(max(Health.good, .bad, .warn) == .bad)
    }
}
