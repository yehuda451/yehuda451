import SwiftUI

struct MoveItemSheet: View {
    let itemsToMove: [URL]
    let onComplete: (URL) -> Void

    var body: some View {
        NavigationStack {
            MoveDestinationPicker(
                directory: FileSystemService.documentsDirectory,
                title: "On My iPhone",
                itemsToMove: itemsToMove,
                onComplete: onComplete
            )
        }
    }
}

private struct MoveDestinationPicker: View {
    @Environment(\.dismiss) private var dismiss
    let directory: URL
    let title: String
    let itemsToMove: [URL]
    let onComplete: (URL) -> Void

    @State private var folders: [FileNode] = []

    var body: some View {
        Group {
            if folders.isEmpty {
                EmptyStateView(systemImage: "folder", title: "No Subfolders", message: "Move the selection into this folder instead.")
            } else {
                List(folders) { folder in
                    NavigationLink {
                        MoveDestinationPicker(directory: folder.url, title: folder.name, itemsToMove: itemsToMove, onComplete: onComplete)
                    } label: {
                        Label(folder.name, systemImage: "folder.fill")
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Move Here") {
                    onComplete(directory)
                    dismiss()
                }
            }
        }
        .onAppear {
            let movingURLs = Set(itemsToMove)
            folders = ((try? FileSystemService.contents(of: directory)) ?? [])
                .filter { $0.isDirectory && !movingURLs.contains($0.url) }
        }
    }
}

#Preview {
    MoveItemSheet(itemsToMove: []) { _ in }
}
