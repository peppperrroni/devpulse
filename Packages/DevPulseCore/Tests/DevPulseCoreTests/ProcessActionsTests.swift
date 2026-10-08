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
