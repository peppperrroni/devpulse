import DevPulseCore
import Foundation
import ServiceManagement

/// Launch at login via SMAppService (shows under System Settings → General → Login Items).
@MainActor
enum LoginItem {
    private static let configuredKey = "loginItemConfigured"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        UserDefaults.standard.set(true, forKey: configuredKey)
    }

    /// Turns autostart on for the first launch of the /Applications copy only.
    static func configureOnFirstLaunch() {
        let configured = UserDefaults.standard.bool(forKey: configuredKey)
        guard LoginItemPolicy.shouldAutoRegister(bundlePath: Bundle.main.bundlePath, alreadyConfigured: configured) else { return }
        try? set(true)
    }
}
