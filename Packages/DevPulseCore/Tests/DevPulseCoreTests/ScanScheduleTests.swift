import Testing
import Foundation
@testable import DevPulseCore

struct ScanScheduleTests {
    let now = Date(timeIntervalSince1970: 100_000)
    let hour: TimeInterval = 3600

    @Test func dueWhenNeverScanned() {
        #expect(ScanSchedule.isDue(lastScan: nil, lastAttempt: nil, intervalHours: 6, now: now))
    }

    @Test func notDueWithinInterval() {
        #expect(!ScanSchedule.isDue(lastScan: now - 5 * hour, lastAttempt: nil, intervalHours: 6, now: now))
        #expect(ScanSchedule.isDue(lastScan: now - 7 * hour, lastAttempt: nil, intervalHours: 6, now: now))
    }

    @Test func cancelledAttemptPostponesTheNextScan() {
        // Stale cache, but the user pressed ✕ a minute ago: do not restart in 5 minutes.
        #expect(!ScanSchedule.isDue(lastScan: now - 30 * hour, lastAttempt: now - 60, intervalHours: 6, now: now))
        #expect(!ScanSchedule.isDue(lastScan: nil, lastAttempt: now - 60, intervalHours: 6, now: now))
        #expect(ScanSchedule.isDue(lastScan: nil, lastAttempt: now - 7 * hour, intervalHours: 6, now: now))
    }
}
