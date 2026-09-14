import SwiftUI
import SwiftData

struct SessionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession?

    @State private var name: String
    @State private var symbolName: String
    @State private var colorHex: String
    @State private var exercises: [SessionExercise]
    @State private var scheduledDays: Set<Weekday>
    @State private var syncsToCalendar: Bool
    @State private var isPresentingPicker = false
    @State private var showsCalendarDeniedAlert = false

    init(session: WorkoutSession?) {
        self.session = session
        _name = State(initialValue: session?.name ?? "")
        _symbolName = State(initialValue: session?.symbolName ?? "figure.strengthtraining.traditional")
        _colorHex = State(initialValue: session?.colorHex ?? SessionColor.blue.rawValue)
        _exercises = State(initialValue: session?.exercises ?? [])
        _scheduledDays = State(initialValue: session?.scheduledDays ?? [])
        _syncsToCalendar = State(initialValue: session?.syncsToCalendar ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Name") {
                    TextField("e.g. Push Day", text: $name)
                }

                Section("Color") {
                    HStack {
                        ForEach(SessionColor.allCases) { option in
                            Circle()
                                .fill(option.color)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if colorHex == option.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = option.rawValue }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Scheduled Days") {
                    WeekdayTogglesRow(selection: $scheduledDays, tint: Color(hex: colorHex))
                }

                Section {
                    Toggle("Add to iPhone Calendar", isOn: $syncsToCalendar)
                        .onChange(of: syncsToCalendar) { _, newValue in
                            if newValue {
                                CalendarSyncManager.shared.requestAccess { result in
                                    switch result {
                                    case .granted:
                                        break
                                    case .blocked:
                                        syncsToCalendar = false
                                        showsCalendarDeniedAlert = true
                                    case .deniedNow:
                                        syncsToCalendar = false
                                    }
                                }
                            }
                        }
                } footer: {
                    Text("Creates a repeating event on this session's scheduled days in a \"Workout Tracker\" calendar.")
                }

                Section("Exercises (\(exercises.count))") {
                    ForEach(exercises.sorted { $0.order < $1.order }) { exercise in
                        exerciseRow(exercise)
                    }
                    .onDelete(perform: deleteExercises)
                    .onMove(perform: moveExercises)

                    Button {
                        isPresentingPicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(session == nil ? "New Session" : "Edit Session")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || exercises.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $isPresentingPicker) {
                ExercisePickerView { picked in
                    add(picked)
                }
            }
            .alert("Calendar Access Denied", isPresented: $showsCalendarDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable Calendar access for Workout Tracker in Settings to sync this session.")
            }
        }
    }

    private func exerciseRow(_ exercise: SessionExercise) -> some View {
        HStack {
            Image(systemName: exercise.category.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName).font(.body)
                if exercise.isTimeBased {
                    Text("\(exercise.sets) sets · \(exercise.durationSeconds)s work · \(exercise.restSeconds)s rest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(exercise.sets) sets · \(exercise.reps) reps · \(exercise.restSeconds)s rest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Stepper("", value: bindingForSets(exercise), in: 1...10)
                .labelsHidden()
        }
    }

    private func bindingForSets(_ exercise: SessionExercise) -> Binding<Int> {
        Binding(
            get: { exercises.first(where: { $0.id == exercise.id })?.sets ?? exercise.sets },
            set: { newValue in
                if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
                    exercises[idx].sets = newValue
                }
            }
        )
    }

    private func add(_ picked: Exercise) {
        let sessionExercise = SessionExercise(
            exerciseName: picked.name,
            category: picked.category,
            isTimeBased: picked.isTimeBased,
            sets: picked.defaultSets,
            reps: picked.defaultReps,
            durationSeconds: picked.defaultDurationSeconds,
            restSeconds: picked.defaultRestSeconds,
            order: exercises.count
        )
        exercises.append(sessionExercise)
    }

    private func deleteExercises(at offsets: IndexSet) {
        var sorted = exercises.sorted { $0.order < $1.order }
        sorted.remove(atOffsets: offsets)
        reindex(sorted)
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = exercises.sorted { $0.order < $1.order }
        sorted.move(fromOffsets: source, toOffset: destination)
        reindex(sorted)
    }

    private func reindex(_ list: [SessionExercise]) {
        exercises = list.enumerated().map { index, exercise in
            var copy = exercise
            copy.order = index
            return copy
        }
    }

    private func save() {
        let target: WorkoutSession
        if let session {
            session.name = name
            session.symbolName = symbolName
            session.colorHex = colorHex
            session.exercises = exercises
            session.scheduledDays = scheduledDays
            session.syncsToCalendar = syncsToCalendar
            target = session
        } else {
            let newSession = WorkoutSession(name: name, symbolName: symbolName, colorHex: colorHex, exercises: exercises, scheduledDays: scheduledDays)
            newSession.syncsToCalendar = syncsToCalendar
            modelContext.insert(newSession)
            target = newSession
        }

        let reminderTime = ReminderSettings.load()
        CalendarSyncManager.shared.sync(session: target, hour: reminderTime.hour, minute: reminderTime.minute)
        dismiss()
    }
}

#Preview {
    SessionEditorView(session: nil)
        .modelContainer(for: [WorkoutSession.self, WorkoutLog.self], inMemory: true)
}
