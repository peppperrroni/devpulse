import Testing
import Foundation
@testable import DevPulseCore

struct ProcessActionsTests {
    private func spawnSleep() throws -> Process {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sleep")
        p.arguments = ["30"]
        try p.run()
        return p
    }

    @Test func lowAndOwnPidsAreNotActionable() {
        #expect(!ProcessActions.isActionable(1))
        #expect(!ProcessActions.isActionable(99))
        #expect(!ProcessActions.isActionable(getpid()))
        #expect(ProcessActions.isActionable(100) || 100 == getpid())
    }

    private func entry(_ pid: pid_t, _ path: String = "/usr/bin/x") -> ProcessEntry {
        ProcessEntry(pid: pid, name: "x", path: path, memory: 1, cpuPercent: 0, isApp: false)
    }

    @Test func loginwindowIsNotActionable() {
        // SIGTERM to loginwindow logs the whole session out.
        let lw = entry(405, "/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow")
        #expect(!ProcessActions.isActionable(lw))
        #expect(ProcessActions.isActionable(entry(405)))
    }

    @Test func targetsAreOnlyVisibleActionableSelectedRows() {
        let visible = [entry(500), entry(501), entry(1),
                       entry(405, "/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow")]
        // 600 is selected but hidden by the filter (or exited); 502 is not selected.
        let targets = ProcessActions.targets(selected: [500, 600, 1, 405], visible: visible + [entry(502)])
        #expect(targets == [500])
    }

    @Test func sigtermStopsChild() throws {
        let p = try spawnSleep()
        try ProcessActions.signal(p.processIdentifier, SIGTERM)
        p.waitUntilExit()
        #expect(!ProcessActions.isAlive(p.processIdentifier))
    }

    @Test func signalOnExitedProcessThrowsNoSuchProcess() throws {
        let p = try spawnSleep()
        let pid = p.processIdentifier
        try ProcessActions.forceKill(pid)
        p.waitUntilExit()
        #expect(throws: KillError.noSuchProcess) { try ProcessActions.signal(pid, SIGTERM) }
    }

    @Test func signallingLaunchdIsNotPermitted() {
        // signal 0 only checks permission; it never affects launchd.
        #expect(throws: KillError.notPermitted) { try ProcessActions.signal(1, 0) }
        #expect(ProcessActions.isAlive(1))
    }

    @Test @MainActor func relaunchRejectsNonApp() async throws {
        let p = try spawnSleep()
        defer { p.terminate() }
        await #expect(throws: RelaunchError.notAnApp) {
            try await ProcessActions.relaunch(p.processIdentifier, timeout: .seconds(1))
        }
    }
}
