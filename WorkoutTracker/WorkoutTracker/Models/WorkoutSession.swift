import Foundation
import SwiftData

/// One exercise as configured inside a specific workout session template.
struct SessionExercise: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var exerciseName: String
    var category: ExerciseCategory
    var isTimeBased: Bool
    var sets: Int
    var reps: Int
    var durationSeconds: Int
    var restSeconds: Int
    var order: Int
}

/// A reusable workout template, e.g. "Push Day" or "Leg Day".
@Model
final class WorkoutSession {
    var id: UUID
    var name: String
    var symbolName: String
    var colorHex: String
    var createdAt: Date
    var exercisesData: Data

    var exercises: [SessionExercise] {
        get {
            (try? JSONDecoder().decode([SessionExercise].self, from: exercisesData)) ?? []
        }
        set {
            exercisesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(name: String, symbolName: String = "figure.strengthtraining.traditional", colorHex: String = "3478F6", exercises: [SessionExercise] = []) {
        self.id = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.exercisesData = Data()
        self.exercises = exercises
    }

    var estimatedMinutes: Int {
        let totalSeconds = exercises.reduce(0) { partial, ex in
            let work = ex.isTimeBased ? ex.durationSeconds : ex.reps * 3
            return partial + (work + ex.restSeconds) * ex.sets
        }
        return max(1, totalSeconds / 60)
    }
}
