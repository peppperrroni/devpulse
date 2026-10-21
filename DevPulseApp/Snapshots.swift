#if DEBUG
import AppKit
import SwiftUI

/// Debug-only: `DEVPULSE_SNAPSHOT=<dir> DevPulse.app/Contents/MacOS/DevPulse` renders the
/// main views to PNG in light and dark appearance and quits. Lets UI be checked
/// without screen-recording permission.
@MainActor
enum Snapshots {
    static func write(to dir: URL, delegate: AppDelegate) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        delegate.processes.refresh()
        Task {
            if ProcessInfo.processInfo.environment["DEVPULSE_SNAPSHOT_SCAN"] != nil {
                let start = Date()
                delegate.disk.rescan()
                while delegate.disk.progress != nil { try? await Task.sleep(for: .milliseconds(500)) }
                let r = delegate.disk.result
                print("scan: \(Int(Date().timeIntervalSince(start))) s, root \(Fmt.bytes(r?.root.size ?? 0)), skipped \(r?.skipped.count ?? 0)")
            }
            for item in delegate.disk.allTop.prefix(14) { print("  \(Fmt.bytes(item.size))  \(item.kind)  \(item.path)") }
            try? await Task.sleep(for: .milliseconds(600))
            delegate.processes.refresh()   // second sample carries CPU %
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                render(delegate.popoverView().background(.background), size: nil, appearance: appearance,
                       to: dir.appending(path: "popover-\(name).png"))
                render(statusTitle(delegate), size: NSSize(width: 160, height: 24), appearance: appearance,
                       to: dir.appending(path: "status-\(name).png"))
                for tab in [CleanerTab.processes, .files] {
                    delegate.navigation.tab = tab
                    await renderWindow(delegate.makeCleanerWindow(), appearance: appearance,
                                       to: dir.appending(path: "window-\(tab)-\(name).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }

    private static func statusTitle(_ delegate: AppDelegate) -> some View {
        Text(AttributedString(StatusTitle.make(delegate.system.snapshot)))
            .padding(4)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Real window off-screen, including title bar and the bridged SwiftUI toolbar.
    private static func renderWindow(_ window: NSWindow, appearance: NSAppearance.Name, to url: URL) async {
        window.appearance = NSAppearance(named: appearance)
        window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
        window.orderFront(nil)
        try? await Task.sleep(for: .milliseconds(700))
        if let frame = window.contentView?.superview,
           let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) {
            frame.cacheDisplay(in: frame.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
        window.orderOut(nil)
    }

    private static func render<V: View>(_ view: V, size: NSSize?, appearance: NSAppearance.Name, to url: URL) {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: appearance)
        let fitting = size ?? host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: fitting), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: fitting)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
