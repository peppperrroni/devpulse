import Testing
import Foundation
@testable import DevPulseCore

struct SystemSnapshotTests {
    @Test func percentagesRoundAndClamp() {
        let s = SystemSnapshot(ramUsed: 10_100, ramTotal: 16_000, pressure: .normal,
                               diskFree: 142, diskTotal: 494)
        #expect(s.ramPercent == 63)
        #expect(s.diskUsedPercent == 71)
        let empty = SystemSnapshot(ramUsed: 5, ramTotal: 0, pressure: .normal, diskFree: 0, diskTotal: 0)
        #expect(empty.ramPercent == 0)
        #expect(empty.diskUsedPercent == 0)
    }

    @Test func overallIsWorstIndicator() {
        let gb = HealthEvaluator.gigabyte
        let s = SystemSnapshot(ramUsed: 1, ramTotal: 2, pressure: .warn,
                               diskFree: 5 * gb, diskTotal: 500 * gb)
        #expect(s.ramHealth == .warn)
        #expect(s.diskHealth == .bad)
        #expect(s.overall == .bad)
    }

    @Test func liveSampleIsSane() {
        let s = SystemSampler.sample()
        #expect(s.ramTotal == ProcessInfo.processInfo.physicalMemory)
        #expect(s.ramUsed > 0 && s.ramUsed <= s.ramTotal)
        #expect(s.diskTotal > 0 && s.diskFree > 0 && s.diskFree < s.diskTotal)
    }
}
