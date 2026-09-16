import Foundation

/// Persists the download queue as JSON in Application Support, deliberately outside
/// `Documents` so it never shows up as clutter in the Files app or the in-app browser.
final class DownloadStore {
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("downloads.json")
    }()

    func load() -> [DownloadItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([DownloadItem].self, from: data)) ?? []
    }

    func save(_ items: [DownloadItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
