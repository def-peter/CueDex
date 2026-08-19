import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var integration: CodexIntegrationInstaller
    @Bindable var loginItem: LoginItemController

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

            Section("Codex") {
                LabeledContent("Integration") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(LocalizedStringKey(integration.status.title))
                            .foregroundStyle(.secondary)
                    }
                }

                integrationAction

                if integration.requiresHookTrust {
                    Label {
                        Text("Open Settings > Hooks in Codex to review and trust CueDex. If CueDex does not appear, restart ChatGPT and try again.")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let error = integration.lastError {
                    Text(LocalizedStringKey(error))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

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
    }

    @ViewBuilder
    private var integrationAction: some View {
        switch integration.status {
        case .installed:
            Button("Disable Integration", systemImage: "link.badge.minus") {
                integration.uninstall()
            }
        case .notInstalled, .unavailable:
            Button("Enable Integration", systemImage: "link.badge.plus") {
                integration.install()
            }
        }
    }

    private var statusColor: Color {
        switch integration.status {
        case .installed: .green
        case .notInstalled: .secondary
        case .unavailable: .red
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
