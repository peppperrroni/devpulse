import AppKit
import SwiftUI

/// Gear menu shared by the popover and the window: settings as native checkmark
/// items, plus Quit (the app has no Dock icon or menu bar of its own).
struct AppMenu: View {
    @Environment(DiskStore.self) private var disk
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        @Bindable var disk = disk
        Menu {
            Toggle("Запускать при входе", isOn: Binding(
                get: { launchAtLogin },
                set: { on in
                    try? LoginItem.set(on)
                    launchAtLogin = LoginItem.isEnabled
                }
            ))
            Picker("Сканировать диск", selection: $disk.intervalHours) {
                ForEach([1, 3, 6, 12, 24], id: \.self) { Text("каждые \($0) ч").tag($0) }
            }
            Divider()
            Button("Выйти из DevPulse") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Label("Настройки", systemImage: "gearshape")
        }
        .menuIndicator(.hidden)
        .help("Настройки и выход")
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}
