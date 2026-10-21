import AppKit
import SwiftUI

struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Menu("Test Cue", systemImage: "play.fill") {
                Button("Test Codex") { model.testCue(source: .codex) }
                Button("Test OpenCode") { model.testCue(source: .opencode) }
            }
            .disabled(model.isPlayingCue)

            Toggle("Pause Notifications", isOn: Binding(
                get: { model.preferences.isPaused },
                set: { model.preferences.isPaused = $0 }
            ))

            Divider()

            Button("Settings", systemImage: "gearshape") {
                openSettings()
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
