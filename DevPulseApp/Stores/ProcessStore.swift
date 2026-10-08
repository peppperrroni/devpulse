import AppKit
import DevPulseCore
import Observation

@Observable @MainActor
final class ProcessStore {
    private(set) var processes: [ProcessEntry] = []
    /// Inline per-row messages: "нет прав", "уже завершён", relaunch failures.
    private(set) var notes: [pid_t: String] = [:]
    /// Rows that ignored SIGTERM for 3 s and now offer SIGKILL.
    private(set) var forceKillOffered: Set<pid_t> = []

    @ObservationIgnored private let sampler = ProcessSampler()
    @ObservationIgnored private var clients = 0
    @ObservationIgnored private var loop: Task<Void, Never>?

    var top5: [ProcessEntry] { Array(processes.prefix(5)) }

    /// Sampling runs only while the popover or the window is visible.
    func attach() {
        clients += 1
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func detach() {
        clients = max(0, clients - 1)
        if clients == 0 {
            loop?.cancel()
            loop = nil
        }
    }

    func refresh() {
        var apps: [pid_t: String] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            apps[app.processIdentifier] = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent
        }
        processes = sampler.sample(apps: apps)
        let alive = Set(processes.map(\.pid))
        forceKillOffered.formIntersection(alive)
    }

    func terminate(_ pids: Set<pid_t>) {
        for pid in pids where ProcessActions.isActionable(pid) {
            do {
                try ProcessActions.terminate(pid)
                notes[pid] = nil
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    if ProcessActions.isAlive(pid) { self?.forceKillOffered.insert(pid) }
                    self?.refresh()
                }
            } catch {
                notes[pid] = Self.describe(error)
            }
        }
    }

    func forceKill(_ pid: pid_t) {
        do {
            try ProcessActions.forceKill(pid)
            forceKillOffered.remove(pid)
        } catch {
            notes[pid] = Self.describe(error)
        }
        refresh()
    }

    func relaunch(_ pid: pid_t) async {
        notes[pid] = "перезапуск…"
        do {
            try await ProcessActions.relaunch(pid)
            notes[pid] = nil
        } catch {
            notes[pid] = switch error {
            case .notAnApp: "не приложение"
            case .didNotExit: "не завершилось за 10 с — перезапуск отменён"
            case .launchFailed(let reason): "не запустилось: \(reason)"
            }
        }
        refresh()
    }

    private static func describe(_ error: KillError) -> String {
        switch error {
        case .notPermitted: "нет прав"
        case .noSuchProcess: "уже завершён"
        case .other(let code): "ошибка \(code)"
        }
    }
}
