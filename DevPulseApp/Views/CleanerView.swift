import SwiftUI

struct CleanerView: View {
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        VStack(spacing: 0) {
            switch navigation.tab {
            case .processes: ProcessesTab(tabs: tabs($navigation.tab))
            case .files: FilesTab(tabs: tabs($navigation.tab))
            }
        }
        .frame(minWidth: 640, minHeight: 440)
        .background(Theme.bg)
    }

    private func tabs(_ binding: Binding<CleanerTab>) -> some View {
        Segmented(options: [(.processes, "Процессы"), (.files, "Файлы")], selection: binding)
            .frame(width: 220)
    }
}
