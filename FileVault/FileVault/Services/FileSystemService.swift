import Foundation

/// Wraps every on-disk operation the file browser and download engine need.
/// Everything lives inside the app's sandboxed `Documents` directory, which is
/// exposed to the iOS Files app via `UIFileSharingEnabled` +
/// `LSSupportsOpeningDocumentsInPlace` in Info.plist.
enum FileSystemService {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Where the download engine saves finished files. Kept as a subfolder so the
    /// root of the Files-app-visible tree stays tidy for anything the user imports.
    static var downloadsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func ensureDirectoryExists(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func ensureParentDirectoryExists(for fileURL: URL) throws {
        try ensureDirectoryExists(at: fileURL.deletingLastPathComponent())
    }

    /// Appends " (n)" before the extension until `suggestedName` no longer collides
    /// with something already in `directory`.
    static func uniqueDestinationURL(in directory: URL, suggestedName: String) -> URL {
        let ext = (suggestedName as NSString).pathExtension
        let base = (suggestedName as NSString).deletingPathExtension
        var candidateName = suggestedName
        var counter = 1
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidateName).path) {
            candidateName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            counter += 1
        }
        return directory.appendingPathComponent(candidateName)
    }

    static func contents(of directory: URL) throws -> [FileNode] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
        return urls.compactMap(FileNode.init)
    }

    @discardableResult
    static func createFolder(named name: String, in directory: URL) throws -> URL {
        let url = uniqueDestinationURL(in: directory, suggestedName: name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    @discardableResult
    static func rename(_ url: URL, to newName: String) throws -> URL {
        let destination = uniqueDestinationURL(in: url.deletingLastPathComponent(), suggestedName: newName)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    @discardableResult
    static func move(_ url: URL, to directory: URL) throws -> URL {
        let destination = uniqueDestinationURL(in: directory, suggestedName: url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: destination)
        return destination
    }

    @discardableResult
    static func copy(_ url: URL, to directory: URL) throws -> URL {
        let destination = uniqueDestinationURL(in: directory, suggestedName: url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    @discardableResult
    static func duplicate(_ url: URL) throws -> URL {
        try copy(url, to: url.deletingLastPathComponent())
    }

    /// Recursively sums file sizes; cheap enough for the folder depths a phone's
    /// local storage realistically has.
    static func size(of url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
        }
        return total
    }

    static func totalDocumentsSize() -> Int64 {
        size(of: documentsDirectory)
    }
}
