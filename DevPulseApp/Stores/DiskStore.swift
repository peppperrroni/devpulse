import DevPulseCore
import Foundation
import Observation

@Observable @MainActor
final class DiskStore {
    private(set) var result: ScanResult? { didSet { recomputeTop() } }
    /// Non-nil while a scan is running.
    private(set) var progress: ScanProgress?
    private(set) var isDeleting = false
    private(set) var lastReport: DeletionReport?
    private(set) var allTop: [TopItem] = []
    private(set) var filesTop: [TopItem] = []
    private(set) var foldersTop: [TopItem] = []

    var intervalHours: Int {
        didSet { UserDefaults.standard.set(intervalHours, forKey: "scanIntervalHours") }
    }

    @ObservationIgnored private let home = NSHomeDirectory()
    @ObservationIgnored private let cache = ScanCache(url: ScanCache.defaultURL)
    @ObservationIgnored private var scanTask: Task<ScanResult, Error>?
    @ObservationIgnored private var scheduler: Task<Void, Never>?

    init() {
        let saved = UserDefaults.standard.integer(forKey: "scanIntervalHours")
        intervalHours = saved > 0 ? saved : 6
        result = cache.load()
        recomputeTop()
    }

    var top5: [TopItem] { Array(allTop.prefix(5)) }

    var needsFullDiskAccess: Bool {
        (result?.skipped.filter { $0.hasPrefix(home + "/Library") }.count ?? 0) > 20
    }

    var isStale: Bool {
        guard let result else { return true }
        return Date().timeIntervalSince(result.date) > Double(intervalHours) * 3600
    }

    /// Checks every 5 minutes whether the cache is older than the interval.
    func start() {
        guard scheduler == nil else { return }
        scheduler = Task { [weak self] in
            while !Task.isCancelled {
                if let self, self.isStale, self.progress == nil { self.rescan() }
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func rescan() {
        guard progress == nil else { return }
        progress = ScanProgress(bytes: 0, items: 0)
        let root = URL(fileURLWithPath: home)
        // The store lives for the whole app run, so a strong capture is fine and
        // avoids a mutable weak capture inside a @Sendable closure.
        let store = self
        let task = Task.detached(priority: .utility) {
            try DiskScanner().scan(root: root) { p in
                Task { @MainActor in if store.progress != nil { store.progress = p } }
            }
        }
        scanTask = task
        Task {
            if let finished = try? await task.value {
                result = finished
                try? cache.save(finished)
            }
            progress = nil
            scanTask = nil
        }
    }

    /// Cancellation keeps the previous cache.
    func cancelScan() {
        scanTask?.cancel()
    }

    func delete(_ items: [TopItem]) async {
        isDeleting = true
        let home = home
        let report = await Task.detached(priority: .userInitiated) { Deleter(home: home).delete(items) }.value
        if var updated = result {
            for path in report.deleted { updated.applyDeletion(of: path) }
            result = updated
            try? cache.save(updated)
        }
        lastReport = report
        isDeleting = false
    }

    func dismissReport() {
        lastReport = nil
    }

    private func recomputeTop() {
        guard let root = result?.root else {
            allTop = []; filesTop = []; foldersTop = []
            return
        }
        allTop = TopItems.all(in: root, home: home, limit: 50)
        filesTop = TopItems.files(in: root, limit: 50)
        foldersTop = TopItems.folders(in: root, home: home, limit: 50)
    }
}
