import Foundation

public enum ScanSchedule {
    /// A background scan is due once the interval has passed since the later of the
    /// last finished scan and the last attempt — so a cancelled scan is not restarted
    /// by the next scheduler tick.
    public static func isDue(lastScan: Date?, lastAttempt: Date?, intervalHours: Int, now: Date) -> Bool {
        guard let last = [lastScan, lastAttempt].compactMap({ $0 }).max() else { return true }
        return now.timeIntervalSince(last) > Double(intervalHours) * 3600
    }
}
