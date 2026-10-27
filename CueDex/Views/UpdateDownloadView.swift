import SwiftUI

struct UpdateDownloadView: View {
    let updates: UpdateController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Download Update")
                .font(.headline)
            if let release = updates.downloadRelease {
                Text(verbatim: "CueDex \(release.version)")
                    .foregroundStyle(.secondary)
                if !updates.canDownload(release) {
                    Text("No matching installer found for this architecture. Please visit the release page.")
                } else {
                    status
                }
                HStack {
                    Link("View Release", destination: release.pageURL)
                    Spacer()
                    actions
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    @ViewBuilder private var status: some View {
        switch updates.downloadState {
        case .idle:
            EmptyView()
        case .downloading(let progress):
            ProgressView(value: progress) {
                Text("Downloading Update…")
            } currentValueLabel: {
                Text(progress, format: .percent.precision(.fractionLength(0)))
            }
        case .verifying:
            ProgressView("Verifying Download…")
                .controlSize(.small)
        case .opening:
            ProgressView("Opening Installer…")
                .controlSize(.small)
        case .ready, .opened:
            if updates.downloadState == .ready {
                Label("Installer Ready", systemImage: "checkmark.circle")
            } else {
                Label("Installer Opened", systemImage: "checkmark.circle")
            }
            Text("Quit CueDex and drag the new version into Applications to complete the update.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(let message):
            Text(LocalizedStringKey(message))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var actions: some View {
        if let release = updates.downloadRelease, updates.canDownload(release) {
            switch updates.downloadState {
            case .idle:
                Button("Download Update") { updates.startDownload() }
            case .downloading, .verifying:
                Button("Cancel Download") { updates.cancelDownload() }
            case .ready, .opened:
                Button("Open Installer") {
                    Task { await updates.openDownloadedInstaller() }
                }
                .keyboardShortcut(.defaultAction)
            case .failed:
                Button("Retry Download") { updates.startDownload() }
            case .opening:
                EmptyView()
            }
        }
    }
}
