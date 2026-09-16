import Foundation

/// Thread-safe scratch space the URLSession delegate callbacks (which fire on a
/// background thread, not the main actor) use to resolve a task to its on-disk
/// destination and its `DownloadItem.id` *synchronously* — critical because the
/// temp file `didFinishDownloadingTo` hands us is deleted the instant the callback
/// returns, so the move to its real destination can't wait for a hop to the main actor.
private final class TaskRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var destinationByTask: [Int: URL] = [:]
    private var itemIDByTask: [Int: UUID] = [:]

    func register(taskIdentifier: Int, destination: URL, itemID: UUID) {
        lock.lock(); defer { lock.unlock() }
        destinationByTask[taskIdentifier] = destination
        itemIDByTask[taskIdentifier] = itemID
    }

    func destination(for taskIdentifier: Int) -> URL? {
        lock.lock(); defer { lock.unlock() }
        return destinationByTask[taskIdentifier]
    }

    func itemID(for taskIdentifier: Int) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        return itemIDByTask[taskIdentifier]
    }

    func remove(taskIdentifier: Int) {
        lock.lock(); defer { lock.unlock() }
        destinationByTask.removeValue(forKey: taskIdentifier)
        itemIDByTask.removeValue(forKey: taskIdentifier)
    }
}

@MainActor
final class DownloadEngine: NSObject, ObservableObject {
    static let shared = DownloadEngine()

    @Published private(set) var downloads: [DownloadItem] = []

    private let store = DownloadStore()
    private let registry = TaskRegistry()
    private var tasksByItemID: [UUID: URLSessionDownloadTask] = [:]
    private var resumeDataByItemID: [UUID: Data] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.filevault.app.background-downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
        downloads = store.load()
        reattachRunningTasks()
    }

    // MARK: - Public API

    @discardableResult
    func startDownload(from url: URL, suggestedName: String? = nil) -> DownloadItem {
        let fileName = suggestedName?.isEmpty == false ? suggestedName! : (url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent)
        let destination = FileSystemService.uniqueDestinationURL(in: FileSystemService.downloadsDirectory, suggestedName: fileName)
        let relativePath = destination.lastPathComponent

        var item = DownloadItem(remoteURL: url, fileName: destination.lastPathComponent, relativePath: relativePath)
        let task = session.downloadTask(with: URLRequest(url: url))
        item.taskIdentifier = task.taskIdentifier

        downloads.insert(item, at: 0)
        tasksByItemID[item.id] = task
        registry.register(taskIdentifier: task.taskIdentifier, destination: destination, itemID: item.id)
        persist()

        task.resume()
        return item
    }

    func pause(_ item: DownloadItem) {
        guard let task = tasksByItemID[item.id] else { return }
        task.cancel { [weak self] resumeData in
            Task { @MainActor in
                guard let self else { return }
                self.resumeDataByItemID[item.id] = resumeData
                self.updateItem(item.id) { $0.status = .paused }
                self.tasksByItemID.removeValue(forKey: item.id)
            }
        }
    }

    func resume(_ item: DownloadItem) {
        let destination = item.fileURL
        let task: URLSessionDownloadTask
        if let resumeData = resumeDataByItemID[item.id] {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: URLRequest(url: item.remoteURL))
        }
        resumeDataByItemID.removeValue(forKey: item.id)
        tasksByItemID[item.id] = task
        registry.register(taskIdentifier: task.taskIdentifier, destination: destination, itemID: item.id)
        updateItem(item.id) {
            $0.status = .downloading
            $0.taskIdentifier = task.taskIdentifier
        }
        task.resume()
    }

    func retry(_ item: DownloadItem) {
        resumeDataByItemID.removeValue(forKey: item.id)
        resume(item)
    }

    func cancel(_ item: DownloadItem) {
        tasksByItemID[item.id]?.cancel()
        tasksByItemID.removeValue(forKey: item.id)
        resumeDataByItemID.removeValue(forKey: item.id)
        if let taskIdentifier = item.taskIdentifier {
            registry.remove(taskIdentifier: taskIdentifier)
        }
        downloads.removeAll { $0.id == item.id }
        persist()
    }

    func removeCompleted(_ item: DownloadItem) {
        downloads.removeAll { $0.id == item.id }
        persist()
    }

    func clearCompleted() {
        downloads.removeAll { $0.status == .completed || $0.status == .failed }
        persist()
    }

    // MARK: - Reattachment

    /// On a cold launch (including the background-events relaunch triggered by
    /// `sessionSendsLaunchEvents`), background `URLSessionTask`s survive under the
    /// same task identifiers. Re-populate the registry so callbacks can find them.
    private func reattachRunningTasks() {
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            Task { @MainActor in
                for task in tasks {
                    guard let downloadTask = task as? URLSessionDownloadTask else { continue }
                    guard let item = self.downloads.first(where: { $0.taskIdentifier == downloadTask.taskIdentifier }) else { continue }
                    self.tasksByItemID[item.id] = downloadTask
                    self.registry.register(taskIdentifier: downloadTask.taskIdentifier, destination: item.fileURL, itemID: item.id)
                }
            }
        }
    }

    // MARK: - State mutation helpers (main actor only)

    private func updateItem(_ id: UUID, _ mutate: (inout DownloadItem) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        mutate(&downloads[index])
        persist()
    }

    private func persist() {
        store.save(downloads)
    }

    fileprivate func handleProgress(taskIdentifier: Int, written: Int64, expected: Int64) {
        guard let itemID = registry.itemID(for: taskIdentifier) else { return }
        updateItem(itemID) {
            $0.downloadedBytes = written
            if expected > 0 { $0.totalBytes = expected }
        }
    }

    fileprivate func handleMoveResult(taskIdentifier: Int, error: Error?) {
        guard let itemID = registry.itemID(for: taskIdentifier) else { return }
        registry.remove(taskIdentifier: taskIdentifier)
        tasksByItemID.removeValue(forKey: itemID)
        if let error {
            updateItem(itemID) {
                $0.status = .failed
                $0.errorDescription = error.localizedDescription
            }
        } else {
            updateItem(itemID) {
                $0.status = .completed
                $0.completedAt = Date()
                if $0.totalBytes <= 0 { $0.totalBytes = $0.downloadedBytes }
                $0.downloadedBytes = $0.totalBytes
            }
        }
    }

    fileprivate func handleTaskCompletion(taskIdentifier: Int, resumeData: Data?, error: NSError) {
        guard let itemID = registry.itemID(for: taskIdentifier) else { return }
        registry.remove(taskIdentifier: taskIdentifier)
        tasksByItemID.removeValue(forKey: itemID)
        if let resumeData {
            resumeDataByItemID[itemID] = resumeData
        }
        // A user-initiated pause cancels the task deliberately; don't overwrite the
        // `.paused` status that `pause(_:)` already set with `.failed`.
        if error.code == NSURLErrorCancelled { return }
        updateItem(itemID) {
            $0.status = .failed
            $0.errorDescription = error.localizedDescription
        }
    }

    fileprivate func handleBackgroundSessionFinishedEvents() {
        AppDelegate.backgroundCompletionHandler?()
        AppDelegate.backgroundCompletionHandler = nil
    }
}

extension DownloadEngine: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskIdentifier = downloadTask.taskIdentifier
        Task { @MainActor in
            self.handleProgress(taskIdentifier: taskIdentifier, written: totalBytesWritten, expected: totalBytesExpectedToWrite)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskIdentifier = downloadTask.taskIdentifier
        guard let destination = registry.destination(for: taskIdentifier) else { return }

        let fileManager = FileManager.default
        var moveError: Error?
        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
        } catch {
            moveError = error
        }

        Task { @MainActor in
            self.handleMoveResult(taskIdentifier: taskIdentifier, error: moveError)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let nsError = error as NSError? else { return }
        let taskIdentifier = task.taskIdentifier
        let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        Task { @MainActor in
            self.handleTaskCompletion(taskIdentifier: taskIdentifier, resumeData: resumeData, error: nsError)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.handleBackgroundSessionFinishedEvents()
        }
    }
}
