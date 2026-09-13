import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [WorkoutSession]
    @Query private var logs: [WorkoutLog]

    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        RemindersSettingsView()
                    } label: {
                        Label("Reminders", systemImage: "bell.badge.fill")
                    }
                }

                Section("Data") {
                    LabeledContent("Sessions", value: "\(sessions.count)")
                    LabeledContent("Logged Workouts", value: "\(logs.count)")
                    Button("Reset All Data", role: .destructive) {
                        showsResetConfirmation = true
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.1.0")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("This will permanently delete all sessions and workout history.", isPresented: $showsResetConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func resetAllData() {
        sessions.forEach { modelContext.delete($0) }
        logs.forEach { modelContext.delete($0) }
        NotificationManager.shared.cancelAll()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
