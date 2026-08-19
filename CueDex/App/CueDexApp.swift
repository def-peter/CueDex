import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AppModel.shared.start()
    }
}

@main
struct CueDexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        Window("CueDex", id: "settings") {
            ContentView(model: model)
        }
        .defaultSize(width: 520, height: 430)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(systemName: model.preferences.isPaused ? "bell.slash.fill" : "bell.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}
