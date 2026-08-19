import SwiftUI

struct ContentView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(
                preferences: model.preferences,
                integration: model.integration,
                loginItem: model.loginItem
            )
            .tabItem { Label("General", systemImage: "gearshape") }

            GlowSettingsView(preferences: model.preferences, testGlow: model.testGlow)
                .tabItem { Label("Glow", systemImage: "sparkles") }

            SoundSettingsView(
                preferences: model.preferences,
                testSound: model.testSound,
                testSpeech: model.testSpeech
            )
                .tabItem { Label("Sound", systemImage: "speaker.wave.2") }

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 430)
        .environment(\.locale, model.preferences.appLanguage.locale)
        .task { model.start() }
    }
}

#Preview {
    ContentView(model: AppModel())
}
