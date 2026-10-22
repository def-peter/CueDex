import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var integration: CodexIntegrationInstaller
    @Bindable var loginItem: LoginItemController
    let model: AppModel
    @State private var actionSource = AttentionSource.codex
    @State private var actionEnablesIntegration = true
    @State private var isConfirmingIntegration = false

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: $preferences.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.nativeName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            integrationSection(.codex)
            integrationSection(.opencode)

            Section("Behavior") {
                Toggle("Pause notifications", isOn: $preferences.isPaused)
                Toggle("Launch at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))

                if let error = loginItem.lastError {
                    Text(LocalizedStringKey(error))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Quiet Hours") {
                Toggle("Enable quiet hours", isOn: $preferences.quietHoursEnabled)
                if preferences.quietHoursEnabled {
                    DatePicker("From", selection: startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: endTime, displayedComponents: .hourAndMinute)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            LocalizedStringKey(actionEnablesIntegration ? "Enable Integration" : "Disable Integration"),
            isPresented: $isConfirmingIntegration,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey(actionEnablesIntegration ? "Enable Integration" : "Disable Integration")) {
                let source = actionSource
                if actionEnablesIntegration {
                    Task { await model.enableIntegration(source) }
                } else {
                    model.disableIntegration(source)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if actionSource == .codex {
                Text("Only CueDex's Stop hook is added or removed. Other hooks and saved cue settings are preserved.")
                Text(verbatim: integration.paths.codexHooksURL.path)
                if actionEnablesIntegration {
                    Text("After enabling integration, open Settings > Hooks in Codex. Find the Stop hook whose command contains cuedex-notify, then review and trust it. CueDex cannot confirm its trust status.")
                }
            } else {
                Text("Only CueDex's global plugin is added or removed. It applies to local projects. Other plugins and saved cue settings are preserved.")
                Text(verbatim: model.opencodeIntegration.paths.opencodePluginURL.path)
                if actionEnablesIntegration {
                    Text("After installation, finish active work and reload your client's OpenCode service. CueDex will not restart it. Configured means installed, not connected.")
                }
            }
        }
    }

    @ViewBuilder
    private func integrationSection(_ source: AttentionSource) -> some View {
        Section {
            if source == .codex {
                Text("Enable Integration installs CueDex's Stop hook automatically. No manual hooks.json edits are needed. Other hooks are preserved.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Hook event") {
                    Text(verbatim: "Stop").foregroundStyle(.secondary)
                }
                LabeledContent("Hook command") {
                    Text(verbatim: integration.paths.helperURL.path)
                        .font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("OpenCode reminders require a global plugin. Enable Integration installs it at the path below; installing CueDex alone is not enough.")
                    .font(.caption).foregroundStyle(.secondary)
                Text(verbatim: model.opencodeIntegration.paths.opencodePluginURL.path)
                    .font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            LabeledContent("Integration") {
                if source == .codex {
                    Text(LocalizedStringKey(integration.status.title)).foregroundStyle(.secondary)
                } else {
                    Text(LocalizedStringKey(model.opencodeIntegration.isInstalled ? "Configured" : "Not enabled"))
                        .foregroundStyle(.secondary)
                }
            }
            if let date = model.lastReceived[source] {
                LabeledContent("Last completion received") {
                    Text(date, format: .dateTime.month().day().hour().minute())
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("Last completion received") { Text("None received").foregroundStyle(.secondary) }
            }
            Button(LocalizedStringKey(model.isInstalled(source) ? "Disable Integration" : "Enable Integration")) {
                actionSource = source
                actionEnablesIntegration = !model.isInstalled(source)
                isConfirmingIntegration = true
            }
            .disabled(source == .opencode && model.opencodeIntegration.isCheckingVersion)

            if source == .codex {
                Text("After enabling integration, open Settings > Hooks in Codex. Find the Stop hook whose command contains cuedex-notify, then review and trust it. CueDex cannot confirm its trust status.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("If the hook is missing, finish active work, restart Codex, and check again. CueDex will not restart it.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Configured means installed, not trusted or connected. A cue preview does not verify integration.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if source == .opencode {
                LabeledContent("Detected CLI version") {
                    Text(verbatim: model.opencodeIntegration.detectedVersion ?? "—")
                        .foregroundStyle(.secondary)
                }
                Text("Requires the actual OpenCode backend to be V2.1.1. OpenChamber may use a different version than the detected CLI.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("After installation, finish active work and reload your client's OpenCode service. CueDex will not restart it. Configured means installed, not connected.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = source == .codex ? integration.lastError : model.opencodeIntegration.lastError {
                Text(LocalizedStringKey(error)).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text(verbatim: source.title)
        }
    }

    private var startTime: Binding<Date> {
        timeBinding(minutes: $preferences.quietHoursStartMinutes)
    }

    private var endTime: Binding<Date> {
        timeBinding(minutes: $preferences.quietHoursEndMinutes)
    }

    private func timeBinding(minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: minutes.wrappedValue / 60,
                    minute: minutes.wrappedValue % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}
