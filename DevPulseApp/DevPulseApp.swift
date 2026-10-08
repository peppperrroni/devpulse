import AppKit
import DevPulseCore
import SwiftUI

@main
struct DevPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let system = SystemStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Fonts.register()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        system.onChange = { [weak self] snapshot in
            self?.statusItem.button?.attributedTitle = StatusTitle.make(snapshot)
        }
        statusItem.button?.attributedTitle = StatusTitle.make(system.snapshot)
        system.start()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: Text("DevPulse").padding())
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
