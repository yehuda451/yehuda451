import Foundation
import UniformTypeIdentifiers

struct FileNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date

    var id: URL { url }

    init?(url: URL) {
        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey,
        ])
        self.url = url
        self.name = values?.name ?? url.lastPathComponent
        self.isDirectory = values?.isDirectory ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.modifiedDate = values?.contentModificationDate ?? .distantPast
    }

    var utType: UTType? {
        UTType(filenameExtension: url.pathExtension)
    }

    var isArchive: Bool {
        url.pathExtension.lowercased() == "zip"
    }

    var systemImageName: String {
        if isDirectory { return "folder.fill" }
        guard let type = utType else { return "doc.fill" }
        if type.conforms(to: .image) { return "photo.fill" }
        if type.conforms(to: .movie) { return "film.fill" }
        if type.conforms(to: .audio) { return "music.note" }
        if type.conforms(to: .pdf) { return "doc.richtext.fill" }
        if type.conforms(to: .archive) || isArchive { return "doc.zipper" }
        if type.conforms(to: .plainText) { return "doc.text.fill" }
        if type.conforms(to: .sourceCode) { return "chevron.left.forwardslash.chevron.right" }
        return "doc.fill"
    }

    var iconColor: String {
        if isDirectory { return "folder" }
        guard let type = utType else { return "doc" }
        if type.conforms(to: .image) { return "image" }
        if type.conforms(to: .movie) { return "movie" }
        if type.conforms(to: .audio) { return "audio" }
        if type.conforms(to: .pdf) { return "pdf" }
        if type.conforms(to: .archive) || isArchive { return "archive" }
        return "doc"
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case dateModified = "Date Modified"
    case size = "Size"

    var id: String { rawValue }

    func sort(_ nodes: [FileNode]) -> [FileNode] {
        let sorted: [FileNode]
        switch self {
        case .name:
            sorted = nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .dateModified:
            sorted = nodes.sorted { $0.modifiedDate > $1.modifiedDate }
        case .size:
            sorted = nodes.sorted { $0.size > $1.size }
        }
        // Folders always float to the top, matching Files-app-style browsers.
        return sorted.filter(\.isDirectory) + sorted.filter { !$0.isDirectory }
    }
}
