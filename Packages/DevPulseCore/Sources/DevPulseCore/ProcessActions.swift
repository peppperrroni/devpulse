import AppKit
import Darwin

public enum KillError: Error, Equatable, Sendable {
    case notPermitted, noSuchProcess, other(Int32)
}

public enum RelaunchError: Error, Equatable, Sendable {
    case notAnApp, didNotExit, launchFailed(String)
}

public enum ProcessActions {
    public static func isActionable(_ pid: pid_t) -> Bool {
        pid >= 100 && pid != getpid()
    }

    /// True while the pid exists, including processes we may not signal.
    public static func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    public static func signal(_ pid: pid_t, _ sig: Int32) throws(KillError) {
        guard kill(pid, sig) != 0 else { return }
        switch errno {
        case EPERM: throw .notPermitted
        case ESRCH: throw .noSuchProcess
        case let code: throw .other(code)
        }
    }

    /// Polite quit: Apple-event quit for GUI apps (lets them save), SIGTERM otherwise.
    @MainActor
    public static func terminate(_ pid: pid_t) throws(KillError) {
        if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular, app.terminate() {
            return
        }
        try signal(pid, SIGTERM)
    }

    public static func forceKill(_ pid: pid_t) throws(KillError) {
        try signal(pid, SIGKILL)
    }

    /// Quit a GUI app, wait for it to exit, launch it again. Never force-kills.
    @MainActor
    public static func relaunch(_ pid: pid_t, timeout: Duration = .seconds(10)) async throws(RelaunchError) {
        guard let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy == .regular,
              let url = app.bundleURL else { throw .notAnApp }
        app.terminate()
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while isAlive(pid) {
            if clock.now >= deadline { throw .didNotExit }
            try? await Task.sleep(for: .milliseconds(200))
        }
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } catch {
            throw .launchFailed(error.localizedDescription)
        }
    }
}
