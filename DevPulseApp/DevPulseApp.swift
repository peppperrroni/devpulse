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
        Fonts.register()
        #if DEBUG
        if let dir = ProcessInfo.processInfo.environment["DEVPULSE_SNAPSHOT"] {
            Snapshots.write(to: URL(fileURLWithPath: dir), delegate: self)
            return
        }
        #endif
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        system.onChange = { [weak self] snapshot in
            self?.statusItem.button?.attributedTitle = StatusTitle.make(snapshot)
        }
        statusItem.button?.attributedTitle = StatusTitle.make(system.snapshot)
        system.start()
        disk.start()

        popover.behavior = .transient
        popover.delegate = self
        let host = NSHostingController(rootView: popoverView())
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
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
            processes.attach()
            processes.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        processes.detach()
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
            let window = NSWindow(contentViewController: NSHostingController(rootView: cleanerView()))
            window.title = "DevPulse"
            window.setContentSize(NSSize(width: 760, height: 520))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            cleanerWindow = window
        }
        if cleanerWindow?.isVisible == false { processes.attach() }
        NSApp.activate()
        cleanerWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        processes.detach()
    }
}
