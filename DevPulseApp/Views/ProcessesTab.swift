import DevPulseCore
import SwiftUI

struct ProcessesTab: View {
    @Environment(ProcessStore.self) private var store
    @Environment(SystemStore.self) private var system
    @Environment(Navigation.self) private var navigation
    @State private var filter = ""
    @State private var sortOrder = [KeyPathComparator(\ProcessEntry.memory, order: .reverse)]
    @State private var forceKillTarget: ProcessEntry?

    private var rows: [ProcessEntry] {
        let filtered = filter.isEmpty ? store.processes
            : store.processes.filter { $0.name.localizedCaseInsensitiveContains(filter) || $0.path.localizedCaseInsensitiveContains(filter) }
        return filtered.sorted(using: sortOrder)
    }

    /// Only rows the user can see: a selection hidden by the filter is never acted on.
    private var actionable: Set<pid_t> {
        ProcessActions.targets(selected: navigation.selectedPIDs, visible: rows)
    }

    private var selectedApp: ProcessEntry? {
        let targets = actionable
        guard targets.count == 1, let pid = targets.first else { return nil }
        return rows.first { $0.pid == pid && $0.isApp }
    }

    var body: some View {
        @Bindable var navigation = navigation
        let s = system.snapshot
        VStack(spacing: 0) {
            SummaryBar(title: "\(Fmt.memory(s.ramUsed)) занято",
                       detail: "из \(Fmt.memory(s.ramTotal)) · \(Fmt.processes(store.processes.count))",
                       fraction: Double(s.ramPercent) / 100, tint: s.ramHealth.tint) { EmptyView() }
            Divider()
            Table(rows, selection: $navigation.selectedPIDs, sortOrder: $sortOrder) {
                TableColumn("Имя", value: \.name) { p in
                    HStack(spacing: 6) {
                        Image(nsImage: store.icon(for: p)).resizable().frame(width: 16, height: 16)
                        Text(p.name).lineLimit(1)
                        if let note = store.notes[p.pid] {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                        if store.forceKillOffered.contains(p.pid) {
                            Button("Завершить принудительно…") { forceKillTarget = p }
                                .controlSize(.small)
                        }
                    }
                    .help(p.path)
                }
                TableColumn("Память", value: \.memory) { p in
                    Text(Fmt.memory(p.memory)).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 90, max: 120)
                TableColumn("ЦП", value: \.cpuPercent) { p in
                    Text(p.cpuPercent, format: .number.precision(.fractionLength(0)))
                        .monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 40, ideal: 56, max: 80)
            }
            .contextMenu(forSelectionType: pid_t.self) { pids in
                let targets = ProcessActions.targets(selected: pids, visible: rows)
                Button("Завершить") { store.terminate(targets) }.disabled(targets.isEmpty)
                if pids.count == 1, let p = rows.first(where: { $0.pid == pids.first }) {
                    if p.isApp { Button("Перезапустить") { Task { await store.relaunch(p.pid) } } }
                    Divider()
                    Button("Показать в Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p.path)])
                    }
                    .disabled(p.path.isEmpty)
                    Button("Скопировать путь") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(p.path, forType: .string)
                    }
                    .disabled(p.path.isEmpty)
                }
            }
        }
        .searchable(text: $filter, placement: .toolbar, prompt: "Поиск процессов")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if let app = selectedApp { Task { await store.relaunch(app.pid) } }
                } label: {
                    Label("Перезапустить", systemImage: "arrow.trianglehead.2.clockwise")
                }
                .disabled(selectedApp == nil)
                .help(selectedApp == nil ? "Выберите одно приложение" : "Закрыть и снова открыть приложение")

                Button(role: .destructive) { store.terminate(actionable) } label: {
                    Label("Завершить", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(actionable.isEmpty)
                .help(actionable.isEmpty ? "Выберите процессы, которые можно завершить" : "Завершить выбранные (⌘⌫)")
            }
        }
        .confirmationDialog("Завершить «\(forceKillTarget?.name ?? "")» принудительно?",
                            isPresented: Binding(get: { forceKillTarget != nil }, set: { if !$0 { forceKillTarget = nil } }),
                            presenting: forceKillTarget) { p in
            Button("Завершить принудительно", role: .destructive) { store.forceKill(p.pid) }
        } message: { _ in
            Text("Процесс не ответил на обычное завершение. Несохранённые данные будут потеряны.")
        }
    }
}
