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
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    let system = SystemStore()
    let processes = ProcessStore()
    let disk = DiskStore()
    let navigation = Navigation()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cleanerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let dir = ProcessInfo.processInfo.environment["DEVPULSE_SNAPSHOT"] {
            Snapshots.write(to: URL(fileURLWithPath: dir), delegate: self)
            return
        }
        #endif
        LoginItem.configureOnFirstLaunch()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        system.onChange = { [weak self] snapshot in self?.updateStatusItem(snapshot) }
        updateStatusItem(system.snapshot)
        system.start()
        disk.start()

        popover.behavior = .transient
        popover.delegate = self
        let host = NSHostingController(rootView: popoverView())
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
    }

    private func updateStatusItem(_ snapshot: SystemSnapshot) {
        statusItem.button?.attributedTitle = StatusTitle.make(snapshot)
        statusItem.button?.setAccessibilityLabel(StatusTitle.accessibilityLabel(snapshot))
    }

    func popoverView() -> some View {
        PopoverView { [weak self] tab, pid, path in self?.showCleaner(tab: tab, pid: pid, path: path) }
            .environment(system).environment(processes).environment(disk)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            processes.attach("popover")
            processes.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        processes.detach("popover")
    }

    func cleanerView() -> some View {
        CleanerView()
            .environment(system).environment(processes).environment(disk).environment(navigation)
    }

    func showCleaner(tab: CleanerTab, pid: pid_t?, path: String?) {
        popover.performClose(nil)
        navigation.tab = tab
        if let pid { navigation.selectedPIDs = [pid] }
        if let path { navigation.selectedPaths = [path] }
        if cleanerWindow == nil {
            let window = makeCleanerWindow()
            window.delegate = self
            window.center()
            cleanerWindow = window
        }
        processes.attach("window")
        NSApp.activate()
        cleanerWindow?.deminiaturize(nil)
        cleanerWindow?.makeKeyAndOrderFront(nil)
    }

    /// Standard titled window; SwiftUI's .toolbar/.searchable are bridged into a
    /// unified NSToolbar, so the chrome and its Liquid Glass come from the system.
    func makeCleanerWindow() -> NSWindow {
        let host = NSHostingController(rootView: cleanerView())
        host.sceneBridgingOptions = [.toolbars, .title]
        let window = NSWindow(contentViewController: host)
        window.title = "DevPulse"
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 820, height: 540))
        window.setFrameAutosaveName("DevPulseCleaner")
        window.isReleasedWhenClosed = false
        return window
    }

    func windowWillClose(_ notification: Notification) {
        processes.detach("window")
    }

    func windowDidMiniaturize(_ notification: Notification) {
        processes.detach("window")
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        processes.attach("window")
    }
}
