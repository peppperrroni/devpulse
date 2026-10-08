import Testing
@testable import DevPulseCore

struct LoginItemPolicyTests {
    @Test func registersInstalledAppOnFirstLaunch() {
        #expect(LoginItemPolicy.shouldAutoRegister(bundlePath: "/Applications/DevPulse.app", alreadyConfigured: false))
    }

    @Test func respectsUserChoiceAfterFirstLaunch() {
        // The user may have switched it off in settings; never re-enable silently.
        #expect(!LoginItemPolicy.shouldAutoRegister(bundlePath: "/Applications/DevPulse.app", alreadyConfigured: true))
    }

    @Test func neverRegistersDevelopmentBuilds() {
        let debug = "/Users/u/devpulse/.claude/worktrees/v1/build/Build/Products/Debug/DevPulse.app"
        #expect(!LoginItemPolicy.shouldAutoRegister(bundlePath: debug, alreadyConfigured: false))
    }
}
