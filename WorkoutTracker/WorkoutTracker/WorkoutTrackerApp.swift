import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([WorkoutSession.self, WorkoutLog.self])
        let configuration = ModelConfiguration(schema: schema)
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
