import AppKit
import SwiftUI

struct AboutSettingsView: View {
    let updates: UpdateController
    private let feedbackAddress = "guanzhen.li@foxmail.com"

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text(verbatim: "CueDex")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 14)

            HStack(spacing: 4) {
                Text("Version")
                Text(verbatim: versionNumber)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 4)

            HStack(spacing: 4) {
                Text("Build")
                Text(verbatim: buildNumber)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)

            Text("CueDex notifies you with screen-edge glow, sound, or speech when Codex finishes responding.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 360)
                .padding(.top, 16)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    Text("Author")
                        .foregroundStyle(.secondary)
                    Text(verbatim: "Peter Li")
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("Feedback Email")
                        .foregroundStyle(.secondary)
                    Link(destination: feedbackURL) {
                        Text(verbatim: feedbackAddress)
                    }
                }

                GridRow {
                    Text("Updates")
                        .foregroundStyle(.secondary)
                    updateControls
                }
            }
            .padding(.top, 24)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var versionNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    private var feedbackURL: URL {
        URL(string: "mailto:\(feedbackAddress)")!
    }

    private var isChecking: Bool {
        updates.state == .checking
    }

    @ViewBuilder
    private var updateControls: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                Task { await updates.checkManually() }
            } label: {
                if isChecking {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for Updates...")
                    }
                } else {
                    Label("Check for Updates", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isChecking)

            switch updates.state {
            case .idle, .checking:
                EmptyView()
            case .upToDate:
                Text("You're up to date.")
                    .foregroundStyle(.secondary)
            case let .updateAvailable(release):
                Link("View Release", destination: release.pageURL)
            case .failed:
                Text("Unable to check for updates.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

#Preview {
    AboutSettingsView(updates: UpdateController())
        .frame(width: 520, height: 430)
}
