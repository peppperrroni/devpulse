import DevPulseCore
import SwiftUI

struct PopoverView: View {
    @Environment(SystemStore.self) private var system
    @Environment(ProcessStore.self) private var processes
    @Environment(DiskStore.self) private var disk
    let openCleaner: (CleanerTab, pid_t?, String?) -> Void
    @State private var segment: CleanerTab = .processes

    var body: some View {
        let s = system.snapshot
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("DevPulse").font(Fonts.display(16)).foregroundStyle(Theme.ink)
                Spacer()
                Text(statusLine(s)).font(Fonts.serif(14)).foregroundStyle(Theme.mute)
            }
            HStack(spacing: 8) {
                GaugeCard(title: "RAM", value: Fmt.bytes(s.ramUsed),
                          fraction: Double(s.ramPercent) / 100, color: Theme.color(s.ramHealth))
                GaugeCard(title: "Диск свободно", value: Fmt.bytes(s.diskFree),
                          fraction: Double(s.diskUsedPercent) / 100,
                          color: s.diskHealth == .good ? Theme.accent : Theme.color(s.diskHealth))
            }
            Segmented(options: [(.processes, "Процессы"), (.files, "Диск")], selection: $segment)
            VStack(spacing: 0) {
                switch segment {
                case .processes:
                    ForEach(Array(processes.top5.enumerated()), id: \.element.pid) { i, p in
                        NumberedRow(index: i + 1, title: p.name, value: Fmt.bytes(p.memory)) {
                            openCleaner(.processes, p.pid, nil)
                        }
                    }
                case .files:
                    if disk.top5.isEmpty {
                        Text(disk.progress == nil ? "Скан ещё не выполнен" : "Сканирую…")
                            .font(Fonts.body(12)).foregroundStyle(Theme.mute).padding(.vertical, 8)
                    }
                    ForEach(Array(disk.top5.enumerated()), id: \.element.id) { i, item in
                        NumberedRow(index: i + 1, title: abbreviate(item.path), value: Fmt.bytes(item.size)) {
                            openCleaner(.files, nil, item.path)
                        }
                    }
                }
            }
            .frame(minHeight: 150, alignment: .top)
            Divider().overlay(Theme.sunken)
            HStack {
                Text(scanLine).font(Fonts.mono(11)).foregroundStyle(Theme.mute)
                Spacer()
                Button("Открыть cleaner") { openCleaner(segment, nil, nil) }
                    .buttonStyle(DPButtonStyle(kind: .primary))
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(Theme.bg)
    }

    private var scanLine: String {
        if disk.progress != nil { return "сканирую…" }
        guard let date = disk.result?.date else { return "скан не выполнен" }
        return "скан \(Fmt.ago(date))"
    }

    private func statusLine(_ s: SystemSnapshot) -> String {
        switch (s.ramHealth, s.diskHealth) {
        case (.good, .good): "всё спокойно"
        case (.bad, .bad), (.bad, .warn), (.warn, .bad), (.warn, .warn): "память и диск на пределе"
        case (_, .good): "память под давлением"
        default: "мало места"
        }
    }
}

func abbreviate(_ path: String) -> String {
    let home = NSHomeDirectory()
    return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
}
