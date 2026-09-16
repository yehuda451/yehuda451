import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var engine = DownloadEngine.shared
    @State private var showAddSheet = false
    @State private var previewURL: URL?

    private var activeDownloads: [DownloadItem] {
        engine.downloads.filter { $0.status == .downloading || $0.status == .paused }
    }

    private var finishedDownloads: [DownloadItem] {
        engine.downloads
            .filter { $0.status == .completed || $0.status == .failed }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if engine.downloads.isEmpty {
                    EmptyStateView(
                        systemImage: "arrow.down.circle",
                        title: "No Downloads Yet",
                        message: "Paste a link to start downloading, or grab files from the built-in browser."
                    )
                } else {
                    List {
                        if !activeDownloads.isEmpty {
                            Section("Downloading") {
                                ForEach(activeDownloads) { item in
                                    ActiveDownloadRow(item: item)
                                }
                            }
                        }
                        if !finishedDownloads.isEmpty {
                            Section("Completed") {
                                ForEach(finishedDownloads) { item in
                                    FinishedDownloadRow(item: item, previewURL: $previewURL)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
                if !finishedDownloads.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Clear Completed", role: .destructive) {
                            engine.clearCompleted()
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddDownloadSheet()
            }
            .quickLookPreview($previewURL)
        }
    }
}

private struct ActiveDownloadRow: View {
    @ObservedObject private var engine = DownloadEngine.shared
    let item: DownloadItem

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(progress: item.progress)
                Image(systemName: item.status == .paused ? "pause.fill" : "arrow.down")
                    .font(.caption2)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileName)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if item.status == .paused {
                    engine.resume(item)
                } else {
                    engine.pause(item)
                }
            } label: {
                Image(systemName: item.status == .paused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .trailing) {
            Button("Cancel", role: .destructive) {
                engine.cancel(item)
            }
        }
    }

    private var subtitle: String {
        let downloaded = item.downloadedBytes.formattedFileSize
        if item.totalBytes > 0 {
            return "\(downloaded) of \(item.totalBytes.formattedFileSize)"
        }
        return item.status == .paused ? "Paused · \(downloaded)" : downloaded
    }
}

private struct FinishedDownloadRow: View {
    @ObservedObject private var engine = DownloadEngine.shared
    let item: DownloadItem
    @Binding var previewURL: URL?

    var body: some View {
        Button {
            if item.status == .completed {
                previewURL = item.fileURL
            } else {
                engine.retry(item)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.status == .failed ? "exclamationmark.triangle.fill" : "doc.fill")
                    .foregroundStyle(item.status == .failed ? .red : .accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.fileName)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if item.status == .failed {
                        Text(item.errorDescription ?? "Download failed — tap to retry")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    } else {
                        Text(item.totalBytes.formattedFileSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                try? FileSystemService.delete(item.fileURL)
                engine.removeCompleted(item)
            }
        }
        .swipeActions(edge: .leading) {
            if item.status == .completed {
                ShareLink(item: item.fileURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.accentColor)
            }
        }
    }
}

#Preview {
    DownloadsView()
}
