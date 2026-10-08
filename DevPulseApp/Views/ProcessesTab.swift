import DevPulseCore
import SwiftUI

struct ProcessesTab<Tabs: View>: View {
    let tabs: Tabs
    @Environment(ProcessStore.self) private var store
    @Environment(SystemStore.self) private var system
    @Environment(Navigation.self) private var navigation
    @State private var filter = ""
    @State private var sortOrder = [KeyPathComparator(\ProcessEntry.memory, order: .reverse)]

    private var rows: [ProcessEntry] {
        let filtered = filter.isEmpty ? store.processes
            : store.processes.filter { $0.name.localizedCaseInsensitiveContains(filter) || $0.path.localizedCaseInsensitiveContains(filter) }
        return filtered.sorted(using: sortOrder)
    }

    private var selectedApp: ProcessEntry? {
        let targets = actionable
        guard targets.count == 1, let pid = targets.first else { return nil }
        return rows.first { $0.pid == pid && $0.isApp }
    }

    /// Only rows the user can see: a selection hidden by the filter is never acted on.
    private var actionable: Set<pid_t> {
        ProcessActions.targets(selected: navigation.selectedPIDs, visible: rows)
    }

    var body: some View {
        @Bindable var navigation = navigation
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "01 / Процессы · \(store.processes.count)")
                    Text("\(Fmt.bytes(system.snapshot.ramUsed)) занято").font(Fonts.display(20)).foregroundStyle(Theme.ink)
                }
                Spacer()
                tabs
            }
            .padding([.horizontal, .top], 16)

            HStack {
                TextField("фильтр", text: $filter).textFieldStyle(.roundedBorder).frame(width: 200)
                Spacer()
                Button("Перезапустить") {
                    if let app = selectedApp { Task { await store.relaunch(app.pid) } }
                }
                .buttonStyle(DPButtonStyle())
                .disabled(selectedApp == nil)
                Button("Завершить") { store.terminate(actionable) }
                    .buttonStyle(DPButtonStyle(kind: .danger))
                    .disabled(actionable.isEmpty)
            }
            .padding(16)

            Table(rows, selection: $navigation.selectedPIDs, sortOrder: $sortOrder) {
                TableColumn("Имя", value: \.name) { p in
                    HStack(spacing: 6) {
                        Text(p.name).font(Fonts.body(12.5)).lineLimit(1)
                        if let note = store.notes[p.pid] {
                            Text(note).font(Fonts.mono(10.5)).foregroundStyle(Theme.danger)
                        }
                        if store.forceKillOffered.contains(p.pid) {
                            Button("Убить принудительно") { store.forceKill(p.pid) }
                                .buttonStyle(DPButtonStyle(kind: .danger)).controlSize(.small)
                        }
                    }
                    .help(p.path)
                }
                TableColumn("Тип") { p in
                    Text(p.isApp ? "app" : "proc")
                        .font(Fonts.mono(10, .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(chip(p.isApp)))
                }
                .width(56)
                TableColumn("RAM", value: \.memory) { p in
                    Text(Fmt.bytes(p.memory)).font(Fonts.mono(11.5, .medium)).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(90)
                TableColumn("CPU", value: \.cpuPercent) { p in
                    Text(String(format: "%.0f%%", p.cpuPercent)).font(Fonts.mono(11.5)).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(60)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func chip(_ isApp: Bool) -> Color {
        isApp ? Color(nsColor: NSColor(hex: 0xA6E04A)).opacity(0.25) : Color(nsColor: NSColor(hex: 0xC08FFF)).opacity(0.2)
    }
}
