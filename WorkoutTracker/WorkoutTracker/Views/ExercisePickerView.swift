import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (Exercise) -> Void

    @State private var searchText = ""
    @State private var isPresentingCustomExercise = false

    private var filteredGroups: [ExerciseGroup] {
        let groups = ExerciseLibrary.grouped()
        guard !searchText.isEmpty else { return groups }
        return groups.compactMap { group in
            let matches = group.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            return matches.isEmpty ? nil : ExerciseGroup(category: group.category, exercises: matches)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups) { group in
                    Section(group.category.rawValue) {
                        ForEach(group.exercises) { exercise in
                            Button {
                                onPick(exercise)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: exercise.category.symbolName)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingCustomExercise = true
                    } label: {
                        Label("Custom", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $isPresentingCustomExercise) {
                CustomExerciseView { exercise in
                    onPick(exercise)
                    dismiss()
                }
            }
        }
    }
}

private struct CustomExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (Exercise) -> Void

    @State private var name = ""
    @State private var category: ExerciseCategory = .fullBody
    @State private var isTimeBased = false
    @State private var sets = 3
    @State private var reps = 10
    @State private var durationSeconds = 30
    @State private var restSeconds = 45

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Cable Fly", text: $name)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Type") {
                    Toggle("Time-based (instead of reps)", isOn: $isTimeBased)
                }
                Section("Defaults") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    if isTimeBased {
                        Stepper("Duration: \(durationSeconds)s", value: $durationSeconds, in: 5...600, step: 5)
                    } else {
                        Stepper("Reps: \(reps)", value: $reps, in: 1...50)
                    }
                    Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...240, step: 5)
                }
            }
            .navigationTitle("Custom Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let exercise = Exercise(
                            name: name,
                            category: category,
                            isTimeBased: isTimeBased,
                            defaultSets: sets,
                            defaultReps: reps,
                            defaultDurationSeconds: durationSeconds,
                            defaultRestSeconds: restSeconds
                        )
                        onCreate(exercise)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
}
