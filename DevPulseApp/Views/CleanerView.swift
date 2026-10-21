import SwiftUI

struct CleanerView: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        Group {
            switch navigation.tab {
            case .processes: ProcessesTab()
            case .files: FilesTab()
            }
        }
        .frame(minWidth: 680, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Раздел", selection: $navigation.tab) {
                    Text("Процессы").tag(CleanerTab.processes)
                    Text("Файлы").tag(CleanerTab.files)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            ToolbarItem(placement: .automatic) { AppMenu() }
        }
    }
}

/// Small secondary line above a table: the tab's key figure and its context.
struct SummaryBar<Trailing: View>: View {
    let title: String
    let detail: String
    let fraction: Double?
    let tint: Color
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.title3.weight(.semibold)).monospacedDigit()
            Text(detail).foregroundStyle(.secondary).monospacedDigit()
            if let fraction {
                Gauge(value: min(1, max(0, fraction))) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(tint)
                    .frame(maxWidth: 160)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
