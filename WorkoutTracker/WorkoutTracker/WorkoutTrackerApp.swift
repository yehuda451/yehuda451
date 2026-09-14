import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([WorkoutSession.self, WorkoutLog.self])
        let configuration = ModelConfiguration(schema: schema)

        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        // The on-disk store couldn't be opened against the current schema
        // (e.g. an unsupported migration from an older build). Rather than
        // crashing on every launch, start fresh from a clean store so the
        // app stays usable.
        let storeURL = configuration.url
        let siblingURLs = ["", "-wal", "-shm"].map {
            storeURL.deletingLastPathComponent().appendingPathComponent(storeURL.lastPathComponent + $0)
        }
        for url in siblingURLs {
            try? FileManager.default.removeItem(at: url)
        }
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    init() {
        NotificationManager.shared.requestAuthorizationIfNeeded { granted in
            if granted {
                NotificationManager.shared.reschedule(with: ReminderSettings.load())
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
