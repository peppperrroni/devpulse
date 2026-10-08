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
            try? await Task.sleep(for: .milliseconds(600))
            delegate.processes.refresh()   // second sample carries CPU %
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                render(delegate.popoverView(), size: nil, appearance: appearance,
                       to: dir.appending(path: "popover-\(name).png"))
                render(statusTitle(delegate), size: NSSize(width: 160, height: 24), appearance: appearance,
                       to: dir.appending(path: "status-\(name).png"))
                for view in extraViews(delegate) {
                    render(view.view, size: view.size, appearance: appearance,
                           to: dir.appending(path: "\(view.name)-\(name).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }

    struct Extra {
        let name: String
        let size: NSSize
        let view: AnyView
    }

    /// Window tabs register here once they exist.
    nonisolated(unsafe) static var extraViews: (AppDelegate) -> [Extra] = { _ in [] }

    private static func statusTitle(_ delegate: AppDelegate) -> some View {
        Text(AttributedString(StatusTitle.make(delegate.system.snapshot)))
            .padding(4)
            .background(Color(nsColor: .windowBackgroundColor))
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
