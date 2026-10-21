import AppKit
import DevPulseCore
import SwiftUI

extension TopItem {
    var name: String { (path as NSString).lastPathComponent }
    var location: String { abbreviate((path as NSString).deletingLastPathComponent) }
    var modifiedOrDistantPast: Date { modified ?? .distantPast }
}

struct FilesTab: View {
    enum Kind: Hashable { case all, files, folders }

    @Environment(DiskStore.self) private var disk
    @Environment(SystemStore.self) private var system
    @Environment(Navigation.self) private var navigation
    @State private var kind: Kind = .all
    @State private var filter = ""
    @State private var sortOrder = [KeyPathComparator(\TopItem.size, order: .reverse)]
    @State private var confirming: [TopItem] = []

    private var rows: [TopItem] {
        let base = switch kind {
        case .all: disk.allTop
        case .files: disk.filesTop
        case .folders: disk.foldersTop
        }
        let filtered = filter.isEmpty ? base : base.filter { $0.path.localizedCaseInsensitiveContains(filter) }
        return filtered.sorted(using: sortOrder)
    }

    /// Visible selected rows only; a folder and a file inside it collapse to the folder.
    private var selectedItems: [TopItem] {
        TopItems.withoutNested(rows.filter { navigation.selectedPaths.contains($0.path) })
    }

    var body: some View {
        @Bindable var navigation = navigation
        let s = system.snapshot
        VStack(spacing: 0) {
            SummaryBar(title: "\(Fmt.bytes(s.diskFree)) свободно",
                       detail: "из \(Fmt.bytes(s.diskTotal)) · \(scanLine)",
                       fraction: Double(s.diskUsedPercent) / 100, tint: s.diskHealth.tint) {
                if disk.progress != nil { ProgressView().controlSize(.small) }
            }
            if disk.needsFullDiskAccess { fdaHint }
            Divider()
            Table(rows, selection: $navigation.selectedPaths, sortOrder: $sortOrder) {
                TableColumn("Имя", value: \.name) { item in
                    HStack(spacing: 6) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: item.path)).resizable().frame(width: 16, height: 16)
                        Text(item.name).lineLimit(1)
                    }
                    .help(item.path)
                }
                TableColumn("Расположение", value: \.location) { item in
                    Text(item.location).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                }
                TableColumn("Размер", value: \.size) { item in
                    Text(Fmt.bytes(item.size)).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 90, max: 120)
                TableColumn("Изменён", value: \.modifiedOrDistantPast) { item in
                    Text(Fmt.modified(item.modified)).monospacedDigit().foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 60, ideal: 80, max: 110)
            }
            .contextMenu(forSelectionType: String.self) { paths in
                let items = TopItems.withoutNested(rows.filter { paths.contains($0.path) })
                Button("Показать в Finder") { reveal(items) }.disabled(items.isEmpty)
                Button("Скопировать путь") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(items.map(\.path).joined(separator: "\n"), forType: .string)
                }
                .disabled(items.isEmpty)
                Divider()
                Button("Удалить навсегда…", role: .destructive) { confirming = items }.disabled(items.isEmpty || disk.isDeleting)
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: disk.progress == nil ? "internaldrive" : "magnifyingglass")
                    } description: {
                        if disk.result == nil && disk.progress == nil { Text("Нажмите «Пересканировать» (⌘R)") }
                    }
                }
            }
        }
        .searchable(text: $filter, placement: .toolbar, prompt: "Поиск по пути")
        .toolbar {
            ToolbarItemGroup {
                Picker("Показывать", selection: $kind) {
                    Text("Всё").tag(Kind.all)
                    Text("Файлы").tag(Kind.files)
                    Text("Папки").tag(Kind.folders)
                }
                .pickerStyle(.menu)
                .help("Что показывать")

                if disk.progress == nil {
                    Button { disk.rescan() } label: { Label("Пересканировать", systemImage: "arrow.clockwise") }
                        .keyboardShortcut("r")
                        .help("Пересканировать домашнюю папку (⌘R)")
                } else {
                    Button { disk.cancelScan() } label: { Label("Остановить скан", systemImage: "stop.circle") }
                        .keyboardShortcut(".")
                        .help("Остановить скан (⌘.) — останется прошлый результат")
                }

                Button { reveal(selectedItems) } label: { Label("Показать в Finder", systemImage: "folder") }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(selectedItems.isEmpty)
                    .help(selectedItems.isEmpty ? "Выберите файл или папку" : "Показать в Finder (⌥⌘R)")

                Button(role: .destructive) { confirming = selectedItems } label: {
                    Label("Удалить навсегда", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(selectedItems.isEmpty || disk.isDeleting)
                .help(disk.isDeleting ? "Идёт удаление…" : selectedItems.isEmpty ? "Выберите файл или папку" : "Удалить навсегда (⌘⌫)")
            }
        }
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { !confirming.isEmpty }, set: { if !$0 { confirming = [] } })) {
            Button("Удалить навсегда", role: .destructive) {
                let items = confirming
                confirming = []
                navigation.selectedPaths = []
                Task { await disk.delete(items) }
            }
        } message: {
            Text(confirmMessage)
        }
        .alert(reportTitle, isPresented: Binding(get: { disk.lastReport != nil }, set: { if !$0 { disk.dismissReport() } })) {
            Button("OK") { disk.dismissReport() }
        } message: {
            Text(reportMessage)
        }
    }

    private func reveal(_ items: [TopItem]) {
        NSWorkspace.shared.activateFileViewerSelecting(items.map { URL(fileURLWithPath: $0.path) })
    }

    private var scanLine: String {
        if let p = disk.progress { return "сканирование: \(Fmt.bytes(p.bytes)), \(Fmt.files(p.items))" }
        guard let date = disk.result?.date else { return "скан не выполнен" }
        return "скан \(Fmt.ago(date))"
    }

    private var emptyTitle: String {
        if disk.progress != nil { return "Сканирование…" }
        if disk.result == nil { return "Диск ещё не сканировался" }
        return filter.isEmpty ? "Нет файлов больше 50 МБ" : "Ничего не найдено"
    }

    private var fdaHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock").foregroundStyle(.secondary)
            Text("Часть ~/Library недоступна. Разрешите DevPulse «Полный доступ к диску», чтобы скан видел всё.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Открыть настройки…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5))
    }

    private var confirmTitle: String {
        confirming.count == 1 ? "Удалить «\(confirming[0].name)» навсегда?" : "Удалить \(Fmt.plural(confirming.count, "объект", "объекта", "объектов")) навсегда?"
    }

    private var confirmMessage: String {
        let total = Fmt.bytes(confirming.reduce(0) { $0 + $1.size })
        return "Будет освобождено \(total). Объекты не попадут в Корзину — удаление необратимо."
    }

    private var reportTitle: String {
        guard let r = disk.lastReport else { return "" }
        return "Освобождено \(Fmt.bytes(r.freed))"
    }

    private var reportMessage: String {
        guard let r = disk.lastReport, !r.failures.isEmpty else { return "" }
        return "Не удалось удалить:\n" + r.failures.map { "\(abbreviate($0.path)) — \($0.reason)" }.joined(separator: "\n")
    }
}
