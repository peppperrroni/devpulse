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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DevPulse").font(.headline)
                Spacer()
                AppMenu().labelStyle(.iconOnly).buttonStyle(.borderless).fixedSize()
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                MetricRow(title: "Память", symbol: "memorychip",
                          detail: "\(Fmt.memory(s.ramUsed)) из \(Fmt.memory(s.ramTotal))",
                          fraction: Double(s.ramPercent) / 100, health: s.ramHealth)
                MetricRow(title: "Диск", symbol: "internaldrive",
                          detail: "\(Fmt.bytes(s.diskFree)) свободно",
                          fraction: Double(s.diskUsedPercent) / 100, health: s.diskHealth)
            }

            Picker("Раздел", selection: $segment) {
                Text("Процессы").tag(CleanerTab.processes)
                Text("Диск").tag(CleanerTab.files)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(spacing: 0) {
                switch segment {
                case .processes:
                    ForEach(Array(processes.top5.enumerated()), id: \.element.pid) { i, p in
                        if i > 0 { Divider() }
                        TopRow(title: p.name, value: Fmt.memory(p.memory)) { openCleaner(.processes, p.pid, nil) }
                    }
                case .files:
                    if disk.top5.isEmpty {
                        Text(disk.progress == nil ? "Диск ещё не сканировался" : "Сканирование…")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                    ForEach(Array(disk.top5.enumerated()), id: \.element.id) { i, item in
                        if i > 0 { Divider() }
                        TopRow(title: abbreviate(item.path), value: Fmt.bytes(item.size)) { openCleaner(.files, nil, item.path) }
                    }
                }
            }

            Divider()
            HStack {
                footnote.font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    if segment == .processes { processes.refresh() } else { disk.rescan() }
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(segment == .files && disk.progress != nil)
                .help(segment == .processes ? "Обновить список процессов" : "Пересканировать диск")
                Button("Открыть DevPulse") { openCleaner(segment, nil, nil) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    @ViewBuilder private var footnote: some View {
        switch segment {
        case .processes:
            if let date = processes.updatedAt {
                Text("Обновлено \(date, style: .relative) назад")
            }
        case .files:
            if disk.progress != nil {
                Text("Сканирование…")
            } else if let date = disk.result?.date {
                Text("Скан \(Fmt.ago(date))")
            } else {
                Text("Скан не выполнен")
            }
        }
    }
}

/// One resource line: label, capacity gauge, used/free detail.
struct MetricRow: View {
    let title: String
    let symbol: String
    let detail: String
    let fraction: Double
    let health: Health

    var body: some View {
        GridRow {
            Label(title, systemImage: symbol)
            Gauge(value: min(1, max(0, fraction))) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(health.tint)
                .frame(minWidth: 70)
            Text(detail)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .gridColumnAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((fraction * 100).rounded())) процентов")
    }
}

private struct TopRow: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 12)
                Text(value).monospacedDigit().foregroundStyle(.secondary)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
