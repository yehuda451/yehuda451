import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.createdAt) private var sessions: [WorkoutSession]

    let date: Date
    let log: WorkoutLog?

    @State private var isPresentingLogPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(date, style: .date)
                    .font(.title2.bold())

                if let log {
                    VStack(spacing: 12) {
                        Image(systemName: log.symbolName)
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: log.colorHex))
                        Text(log.sessionName)
                            .font(.title3.bold())
                        Text("\(log.durationMinutes) min · \(log.exercisesCompleted)/\(log.totalExercises) exercises")
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            modelContext.delete(log)
                            dismiss()
                        } label: {
                            Label("Remove Entry", systemImage: "trash")
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    ContentUnavailableView(
                        "Rest Day",
                        systemImage: "moon.zzz.fill",
                        description: Text("No workout was logged on this day.")
                    )

                    if !sessions.isEmpty {
                        Button {
                            isPresentingLogPicker = true
                        } label: {
                            Label("Log a Workout", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingLogPicker) {
                ManualLogView(date: date, sessions: sessions) {
                    dismiss()
                }
            }
        }
    }
}

/// Lets the user retroactively mark a session as completed on a given day,
/// for workouts done outside the app's own timer.
private struct ManualLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let sessions: [WorkoutSession]
    let onSaved: () -> Void

    @State private var selectedSession: WorkoutSession?
    @State private var durationMinutes = 30

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    ForEach(sessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            HStack {
                                Image(systemName: session.symbolName)
                                    .foregroundStyle(Color(hex: session.colorHex))
                                Text(session.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSession?.id == session.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section("Duration") {
                    Stepper("\(durationMinutes) minutes", value: $durationMinutes, in: 1...240, step: 5)
                }
            }
            .navigationTitle("Log Workout")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(selectedSession == nil)
                }
            }
            .onAppear { selectedSession = sessions.first }
        }
    }

    private func save() {
        guard let session = selectedSession else { return }
        let log = WorkoutLog(
            date: date,
            sessionName: session.name,
            sessionID: session.id,
            symbolName: session.symbolName,
            colorHex: session.colorHex,
            durationMinutes: durationMinutes,
            exercisesCompleted: session.exercises.count,
            totalExercises: session.exercises.count
        )
        modelContext.insert(log)
        onSaved()
    }
}

#Preview {
    DayDetailView(date: .now, log: nil)
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
