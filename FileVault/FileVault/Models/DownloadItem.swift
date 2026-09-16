import Foundation

enum DownloadStatus: String, Codable {
    case downloading
    case paused
    case completed
    case failed
}

struct DownloadItem: Identifiable, Codable, Equatable {
    let id: UUID
    var remoteURL: URL
    var fileName: String
    /// Path relative to `FileSystemService.downloadsDirectory`.
    var relativePath: String
    var totalBytes: Int64
    var downloadedBytes: Int64
    var status: DownloadStatus
    var createdAt: Date
    var completedAt: Date?
    var errorDescription: String?
    /// The `URLSessionTask.taskIdentifier` backing this download, so the engine can
    /// reattach to a still-running background task after the app relaunches.
    var taskIdentifier: Int?

    init(
        id: UUID = UUID(),
        remoteURL: URL,
        fileName: String,
        relativePath: String,
        totalBytes: Int64 = 0,
        downloadedBytes: Int64 = 0,
        status: DownloadStatus = .downloading,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        errorDescription: String? = nil,
        taskIdentifier: Int? = nil
    ) {
        self.id = id
        self.remoteURL = remoteURL
        self.fileName = fileName
        self.relativePath = relativePath
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.errorDescription = errorDescription
        self.taskIdentifier = taskIdentifier
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(downloadedBytes) / Double(totalBytes)))
    }

    var fileURL: URL {
        FileSystemService.downloadsDirectory.appendingPathComponent(relativePath)
    }
}
