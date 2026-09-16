import SwiftUI

private enum BrowserViewMode: String {
    case list, grid
}

struct FileBrowserView: View {
    let directory: URL
    let title: String

    @State private var nodes: [FileNode] = []
    @State private var sortOption: SortOption = .name
    @State private var searchText = ""
    @State private var viewMode: BrowserViewMode = .list
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<URL>()

    @State private var previewURL: URL?
    @State private var showNewFolderAlert = false
    @State private var showImporter = false
    @State private var showMoveSheet = false
    @State private var itemsToMove: [URL] = []
    @State private var renamingNode: FileNode?
    @State private var errorMessage: String?
    @State private var showError = false

    private var filteredNodes: [FileNode] {
        let base = searchText.isEmpty ? nodes : nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return sortOption.sort(base)
    }

    var body: some View {
        Group {
            if nodes.isEmpty {
                EmptyStateView(
                    systemImage: "folder",
                    title: "Empty Folder",
                    message: "Import files from Files, or download something from the Browser tab."
                )
            } else if viewMode == .list {
                listView
            } else {
                gridView
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText)
        .environment(\.editMode, $editMode)
        .toolbar { toolbarContent }
        .refreshable { reload() }
        .onAppear { reload() }
        .quickLookPreview($previewURL)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            handleImport(result)
        }
        .textFieldAlert(isPresented: $showNewFolderAlert, title: "New Folder", placeholder: "Folder name") { name in
            createFolder(name)
        }
        .textFieldAlert(
            isPresented: Binding(get: { renamingNode != nil }, set: { if !$0 { renamingNode = nil } }),
            title: "Rename",
            placeholder: "Name",
            initialText: renamingNode?.name ?? ""
        ) { newName in
            if let node = renamingNode {
                _ = try? FileSystemService.rename(node.url, to: newName)
            }
            renamingNode = nil
            reload()
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveItemSheet(itemsToMove: itemsToMove) { destination in
                moveSelection(to: destination)
            }
        }
        .alert("Something Went Wrong", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - List / Grid

    private var listView: some View {
        List(selection: $selection) {
            ForEach(filteredNodes) { node in
                rowView(for: node)
            }
        }
        .listStyle(.plain)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 16)]
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(filteredNodes) { node in
                    gridCell(for: node)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func rowView(for node: FileNode) -> some View {
        Group {
            if node.isDirectory {
                NavigationLink {
                    FileBrowserView(directory: node.url, title: node.name)
                } label: {
                    rowLabel(node)
                }
            } else {
                Button {
                    previewURL = node.url
                } label: {
                    rowLabel(node)
                }
                .foregroundStyle(.primary)
            }
        }
        .contextMenu { contextMenuItems(for: node) }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { delete([node.url]) }
            Button("Rename") { renamingNode = node }.tint(.blue)
        }
        .swipeActions(edge: .leading) {
            if !node.isDirectory {
                ShareLink(item: node.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func rowLabel(_ node: FileNode) -> some View {
        HStack(spacing: 14) {
            FileIconView(node: node)
            VStack(alignment: .leading, spacing: 3) {
                Text(node.name).lineLimit(1)
                if !node.isDirectory {
                    Text("\(node.size.formattedFileSize) · \(node.modifiedDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func gridCell(for node: FileNode) -> some View {
        Group {
            if node.isDirectory {
                NavigationLink {
                    FileBrowserView(directory: node.url, title: node.name)
                } label: {
                    gridCellLabel(node)
                }
            } else {
                Button {
                    previewURL = node.url
                } label: {
                    gridCellLabel(node)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenuItems(for: node) }
    }

    private func gridCellLabel(_ node: FileNode) -> some View {
        VStack(spacing: 6) {
            FileIconView(node: node, size: 44)
            Text(node.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .frame(width: 96)
    }

    @ViewBuilder
    private func contextMenuItems(for node: FileNode) -> some View {
        Button {
            renamingNode = node
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            duplicate(node)
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button {
            itemsToMove = [node.url]
            showMoveSheet = true
        } label: {
            Label("Move", systemImage: "folder")
        }
        if node.isArchive {
            Button {
                extract(node)
            } label: {
                Label("Extract", systemImage: "archivebox")
            }
        } else {
            Button {
                compress([node.url])
            } label: {
                Label("Compress", systemImage: "doc.zipper")
            }
        }
        if !node.isDirectory {
            ShareLink(item: node.url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        Divider()
        Button(role: .destructive) {
            delete([node.url])
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Import Files", systemImage: "square.and.arrow.down.on.square")
                }
                Button {
                    viewMode = viewMode == .list ? .grid : .list
                } label: {
                    Label(viewMode == .list ? "Grid View" : "List View", systemImage: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                }
                Picker("Sort By", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                Button(editMode.isEditing ? "Done Selecting" : "Select") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                    if !editMode.isEditing { selection.removeAll() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            if editMode.isEditing {
                Button {
                    itemsToMove = Array(selection)
                    showMoveSheet = true
                } label: {
                    Image(systemName: "folder")
                }
                .disabled(selection.isEmpty)

                Button {
                    compress(Array(selection))
                } label: {
                    Image(systemName: "doc.zipper")
                }
                .disabled(selection.isEmpty)

                ShareLink(items: Array(selection)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(selection.isEmpty)

                Spacer()

                Button(role: .destructive) {
                    delete(Array(selection))
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(selection.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func reload() {
        nodes = (try? FileSystemService.contents(of: directory)) ?? []
    }

    private func createFolder(_ name: String) {
        do {
            _ = try FileSystemService.createFolder(named: name, in: directory)
            reload()
        } catch {
            present(error)
        }
    }

    private func duplicate(_ node: FileNode) {
        do {
            _ = try FileSystemService.duplicate(node.url)
            reload()
        } catch {
            present(error)
        }
    }

    private func delete(_ urls: [URL]) {
        for url in urls {
            try? FileSystemService.delete(url)
        }
        selection.subtract(urls)
        reload()
    }

    private func moveSelection(to destination: URL) {
        for url in itemsToMove {
            _ = try? FileSystemService.move(url, to: destination)
        }
        itemsToMove = []
        selection.removeAll()
        reload()
    }

    private func compress(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let baseName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Archive"
        let destination = FileSystemService.uniqueDestinationURL(in: directory, suggestedName: "\(baseName).zip")
        Task.detached(priority: .userInitiated) {
            do {
                try ZipService.zip(items: urls, to: destination)
                await MainActor.run { reload() }
            } catch {
                await MainActor.run { present(error) }
            }
        }
    }

    private func extract(_ node: FileNode) {
        let destination = FileSystemService.uniqueDestinationURL(
            in: directory,
            suggestedName: node.url.deletingPathExtension().lastPathComponent
        )
        Task.detached(priority: .userInitiated) {
            do {
                try ZipService.unzip(node.url, to: destination)
                await MainActor.run { reload() }
            } catch {
                await MainActor.run { present(error) }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                do {
                    _ = try FileSystemService.copy(url, to: directory)
                } catch {
                    present(error)
                }
            }
            reload()
        case .failure(let error):
            present(error)
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

#Preview {
    NavigationStack {
        FileBrowserView(directory: FileSystemService.documentsDirectory, title: "Files")
    }
}
