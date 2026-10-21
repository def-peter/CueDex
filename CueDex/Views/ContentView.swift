import SwiftUI

struct ContentView: View {
    let model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        TabView {
            GeneralSettingsView(
                preferences: model.preferences,
                integration: model.integration,
                loginItem: model.loginItem,
                model: model
            )
            .tabItem { Label("General", systemImage: "gearshape") }

            ReminderSettingsView(model: model)
                .tabItem { Label("Cues", systemImage: "bell") }

            AboutSettingsView(updates: model.updates)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 660, height: 500)
        .environment(\.locale, model.preferences.appLanguage.locale)
        .task { model.start() }
        .alert(
            "Update Available",
            isPresented: updateAlertPresented,
            presenting: model.updates.presentedRelease
        ) { release in
            Button("View Release") {
                openURL(release.pageURL)
                model.updates.dismissUpdateAlert()
            }
            Button("Later", role: .cancel) {
                model.updates.dismissUpdateAlert()
            }
        } message: { release in
            Text("CueDex \(release.version) is available. You are using \(model.updates.currentVersion).")
        }
    }

    private var updateAlertPresented: Binding<Bool> {
        Binding(
            get: { model.updates.presentedRelease != nil },
            set: { isPresented in
                if !isPresented {
                    model.updates.dismissUpdateAlert()
                }
            }
        )
    }
}

#Preview {
    ContentView(model: AppModel())
}
