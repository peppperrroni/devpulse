import AppKit
import DevPulseCore
import SwiftUI

struct FilesTab<Tabs: View>: View {
    enum Filter: Hashable { case all, files, folders }

    let tabs: Tabs
    @Environment(DiskStore.self) private var disk
    @Environment(SystemStore.self) private var system
    @Environment(Navigation.self) private var navigation
    @State private var filter: Filter = .all
    @State private var confirming: [TopItem] = []
    @State private var showSettings = false

    private var rows: [TopItem] {
        switch filter {
        case .all: disk.allTop
        case .files: disk.filesTop
        case .folders: disk.foldersTop
        }
    }

    private var selectedItems: [TopItem] {
        rows.filter { navigation.selectedPaths.contains($0.path) }
    }

    var body: some View {
        @Bindable var navigation = navigation
        VStack(alignment: .leading, spacing: 0) {
            header
            if disk.needsFullDiskAccess { fdaHint }
            HStack {
                Segmented(options: [(.all, "Все"), (.files, "Файлы"), (.folders, "Папки")], selection: $filter)
                    .frame(width: 240)
                Spacer()
                Button("Показать в Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(selectedItems.map { URL(fileURLWithPath: $0.path) })
                }
                .buttonStyle(DPButtonStyle())
                .disabled(selectedItems.isEmpty)
                Button(disk.isDeleting ? "Удаляю…" : "Удалить навсегда") { confirming = selectedItems }
                    .buttonStyle(DPButtonStyle(kind: .danger))
                    .disabled(selectedItems.isEmpty || disk.isDeleting)
            }
            .padding(16)

            Table(rows, selection: $navigation.selectedPaths) {
                TableColumn("Путь") { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.kind == .folder ? "folder" : "doc").foregroundStyle(Theme.mute)
                        Text(abbreviate(item.path)).font(Fonts.body(12.5)).lineLimit(1).truncationMode(.middle)
                    }
                    .help(item.path)
                }
                TableColumn("Размер") { item in
                    Text(Fmt.bytes(item.size)).font(Fonts.mono(11.5, .medium)).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(90)
                TableColumn("Изменён") { item in
                    Text(Fmt.modified(item.modified)).font(Fonts.mono(11.5)).foregroundStyle(Theme.mute)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(80)
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if rows.isEmpty {
                    Text(disk.progress == nil ? "Скан ещё не выполнен" : "Сканирую…")
                        .font(Fonts.body(13)).foregroundStyle(Theme.mute)
                }
            }
        }
        .sheet(isPresented: Binding(get: { !confirming.isEmpty }, set: { if !$0 { confirming = [] } })) {
            ConfirmDeleteSheet(items: confirming) {
                let items = confirming
                confirming = []
                navigation.selectedPaths = []
                Task { await disk.delete(items) }
            } cancel: {
                confirming = []
            }
        }
        .alert(reportTitle, isPresented: Binding(get: { disk.lastReport != nil }, set: { if !$0 { disk.dismissReport() } })) {
            Button("OK") { disk.dismissReport() }
        } message: {
            Text(reportMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    SectionLabel(text: "02 / Файлы · \(scanLine)")
                    if disk.progress == nil {
                        Button { disk.rescan() } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).foregroundStyle(Theme.mute).help("Пересканировать")
                    } else {
                        Button { disk.cancelScan() } label: { Image(systemName: "xmark.circle") }
                            .buttonStyle(.plain).foregroundStyle(Theme.mute).help("Остановить скан")
                    }
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .buttonStyle(.plain).foregroundStyle(Theme.mute)
                        .popover(isPresented: $showSettings) { settings }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Fmt.bytes(system.snapshot.diskFree)) свободно").font(Fonts.display(20)).foregroundStyle(Theme.ink)
                    Text("из \(Fmt.bytes(system.snapshot.diskTotal))").font(Fonts.serif(16)).foregroundStyle(Theme.mute)
                }
            }
            Spacer()
            tabs
        }
        .padding([.horizontal, .top], 16)
    }

    private var scanLine: String {
        if let p = disk.progress { return "сканирую · \(Fmt.bytes(p.bytes)) · \(p.items) файлов" }
        guard let date = disk.result?.date else { return "скан не выполнен" }
        return "скан \(Fmt.ago(date))"
    }

    private var fdaHint: some View {
        HStack {
            Text("Часть ~/Library недоступна — выдай DevPulse «Полный доступ к диску», чтобы скан видел всё.")
                .font(Fonts.body(12)).foregroundStyle(Theme.ink)
            Spacer()
            Button("Открыть настройки") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            .buttonStyle(DPButtonStyle())
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: NSColor(hex: 0xFFB347)).opacity(0.2)))
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var settings: some View {
        @Bindable var disk = disk
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Настройки")
            Stepper("Скан каждые \(disk.intervalHours) ч", value: $disk.intervalHours, in: 1...48)
                .font(Fonts.body(12.5))
        }
        .padding(14)
        .frame(width: 240)
    }

    private var reportTitle: String {
        guard let r = disk.lastReport else { return "" }
        return "Освобождено \(Fmt.bytes(r.freed))"
    }

    private var reportMessage: String {
        guard let r = disk.lastReport, !r.failures.isEmpty else { return "" }
        return "Не удалось:\n" + r.failures.map { "\(abbreviate($0.path)) — \($0.reason)" }.joined(separator: "\n")
    }
}

struct ConfirmDeleteSheet: View {
    let items: [TopItem]
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Удалить навсегда")
            Text(Fmt.bytes(items.reduce(0) { $0 + $1.size })).font(Fonts.display(22)).foregroundStyle(Theme.ink)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        HStack {
                            Text(abbreviate(item.path)).font(Fonts.mono(11.5)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(Fmt.bytes(item.size)).font(Fonts.mono(11.5, .medium))
                        }
                    }
                }
            }
            .frame(maxHeight: 160)
            Text("Удаление необратимо — в Корзину не попадёт.").font(Fonts.body(12)).foregroundStyle(Theme.danger)
            HStack {
                Spacer()
                Button("Отмена", action: cancel).buttonStyle(DPButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Удалить навсегда", action: confirm).buttonStyle(DPButtonStyle(kind: .danger))
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(Theme.bg)
    }
}
