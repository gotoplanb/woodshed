import SwiftUI

struct SettingsView: View {
    @Environment(StorageService.self) private var storage

    var body: some View {
        @Bindable var storage = storage
        Form {
            SwiftUI.Section("Defaults") {
                TextField("Default Instrument", text: $storage.settings.defaultInstrument)
            }

            SwiftUI.Section("Practice Mode") {
                Picker("Countdown", selection: $storage.settings.countdownSeconds) {
                    Text("None").tag(0)
                    Text("1 second").tag(1)
                    Text("2 seconds").tag(2)
                    Text("3 seconds").tag(3)
                }

                Picker("Tab Display", selection: $storage.settings.tabDisplayMode) {
                    ForEach(AppSettings.TabDisplayMode.allCases) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: storage.settings.defaultInstrument) { _, _ in storage.saveSettings() }
        .onChange(of: storage.settings.countdownSeconds) { _, _ in storage.saveSettings() }
        .onChange(of: storage.settings.tabDisplayMode) { _, _ in storage.saveSettings() }
    }
}
