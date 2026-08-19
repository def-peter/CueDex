import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.start()
    }
}

@main
struct CueDexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            CueDexStatusIcon(isPaused: model.preferences.isPaused)
                .accessibilityLabel("CueDex")
                .help("CueDex")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            ContentView(model: model)
        }
    }
}
