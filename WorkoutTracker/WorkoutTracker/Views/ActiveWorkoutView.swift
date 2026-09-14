import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let session: WorkoutSession
    @StateObject private var timer: WorkoutTimerManager
    @State private var showsExitConfirmation = false

    init(session: WorkoutSession) {
        self.session = session
        _timer = StateObject(wrappedValue: WorkoutTimerManager(exercises: session.exercises))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if timer.phase == .finished {
                    summaryView
                } else {
                    activeView
                }
            }
            .padding()
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("End") {
                        if timer.phase == .finished {
                            dismiss()
                        } else {
                            showsExitConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog("End this workout?", isPresented: $showsExitConfirmation, titleVisibility: .visible) {
                Button("End Without Saving", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { timer.start() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    timer.refresh()
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var activeView: some View {
        VStack(spacing: 28) {
            ProgressView(value: timer.progress)
                .tint(Color(hex: session.colorHex))

            Text("Exercise \(min(timer.exerciseIndex + 1, timer.totalExercises)) of \(timer.totalExercises)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let exercise = timer.currentExercise {
                VStack(spacing: 6) {
                    Text(exercise.exerciseName)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text("Set \(timer.setIndex + 1) of \(exercise.sets)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(timer.phase == .rest ? "REST" : "WORK")
                .font(.caption.bold())
                .kerning(2)
                .foregroundStyle(timer.phase == .rest ? .orange : .green)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background((timer.phase == .rest ? Color.orange : Color.green).opacity(0.15), in: Capsule())

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: countdownFraction)
                    .stroke(timer.phase == .rest ? Color.orange : Color(hex: session.colorHex), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.secondsRemaining)
                Text(timer.formattedTime(timer.secondsRemaining))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 220, height: 220)
            .padding(.vertical, 8)

            HStack(spacing: 20) {
                Button {
                    timer.toggle()
                } label: {
                    Label(timer.isRunning ? "Pause" : "Start", systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: session.colorHex), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }

                Button {
                    timer.skip()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                }
            }

            Spacer()
        }
    }

    private var countdownFraction: Double {
        guard let exercise = timer.currentExercise else { return 0 }
        let total = timer.phase == .rest ? max(exercise.restSeconds, 1) : max(exercise.isTimeBased ? exercise.durationSeconds : exercise.reps * 3, 1)
        return 1 - (Double(timer.secondsRemaining) / Double(total))
    }

    private var summaryView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Workout Complete!")
                .font(.title.bold())
            Text("\(session.name) · \(timer.elapsedMinutes) min")
                .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Save & Finish")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: session.colorHex), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .onAppear { saveLog() }
    }

    private func saveLog() {
        let calendar = Calendar.current
        if let existing = try? modelContext.fetch(FetchDescriptor<WorkoutLog>()).first(where: {
            calendar.isDateInToday($0.date) && $0.sessionID == session.id
        }) {
            existing.durationMinutes = max(existing.durationMinutes, timer.elapsedMinutes)
            return
        }

        let log = WorkoutLog(
            date: .now,
            sessionName: session.name,
            sessionID: session.id,
            symbolName: session.symbolName,
            colorHex: session.colorHex,
            durationMinutes: max(timer.elapsedMinutes, 1),
            exercisesCompleted: timer.totalExercises,
            totalExercises: timer.totalExercises
        )
        modelContext.insert(log)
    }
}

#Preview {
    ActiveWorkoutView(session: WorkoutSession(name: "Push Day", exercises: [
        SessionExercise(exerciseName: "Push-Ups", category: .chest, isTimeBased: false, sets: 3, reps: 12, durationSeconds: 0, restSeconds: 30, order: 0)
    ]))
    .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
