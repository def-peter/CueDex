import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("Test Cue", systemImage: "play.fill", action: model.testCue)

            Toggle("Pause Notifications", isOn: Binding(
                get: { model.preferences.isPaused },
                set: { model.preferences.isPaused = $0 }
            ))

            Divider()

            Button("Settings", systemImage: "gearshape") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit CueDex", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .environment(\.locale, model.preferences.appLanguage.locale)
    }
}
