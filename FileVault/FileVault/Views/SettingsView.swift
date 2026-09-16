import SwiftUI

struct SettingsView: View {
    @State private var storageUsed: Int64 = 0
    @State private var showClearConfirmation = false
    @ObservedObject private var engine = DownloadEngine.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Storage") {
                    HStack {
                        Label("Used by FileVault", systemImage: "internaldrive")
                        Spacer()
                        Text(storageUsed.formattedFileSize)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Active Downloads", systemImage: "arrow.down.circle")
                        Spacer()
                        Text("\(engine.downloads.filter { $0.status == .downloading || $0.status == .paused }.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear Completed Downloads", systemImage: "trash")
                    }
                } footer: {
                    Text("Removes finished downloads from the list. Files already saved to Files stay untouched.")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FileVault")
                            .font(.headline)
                        Text("A download manager and file browser for iPhone: grab files from the built-in browser or a direct link, then organize, preview, zip/unzip, and share them — all backed by the on-device Files app.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .onAppear { storageUsed = FileSystemService.totalDocumentsSize() }
            .confirmationDialog(
                "Clear all completed and failed downloads?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Completed", role: .destructive) {
                    engine.clearCompleted()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
