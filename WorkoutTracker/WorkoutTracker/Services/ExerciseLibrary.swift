import Foundation

/// Built-in exercise catalog used to populate the exercise picker.
enum ExerciseLibrary {
    static let all: [Exercise] = [
        Exercise(name: "Push-Ups", category: .chest, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 45),
        Exercise(name: "Bench Press", category: .chest, isTimeBased: false, defaultSets: 4, defaultReps: 8, defaultDurationSeconds: 0, defaultRestSeconds: 90),
        Exercise(name: "Incline Dumbbell Press", category: .chest, isTimeBased: false, defaultSets: 3, defaultReps: 10, defaultDurationSeconds: 0, defaultRestSeconds: 75),
        Exercise(name: "Chest Dips", category: .chest, isTimeBased: false, defaultSets: 3, defaultReps: 10, defaultDurationSeconds: 0, defaultRestSeconds: 60),

        Exercise(name: "Pull-Ups", category: .back, isTimeBased: false, defaultSets: 4, defaultReps: 8, defaultDurationSeconds: 0, defaultRestSeconds: 90),
        Exercise(name: "Bent-Over Row", category: .back, isTimeBased: false, defaultSets: 4, defaultReps: 10, defaultDurationSeconds: 0, defaultRestSeconds: 75),
        Exercise(name: "Lat Pulldown", category: .back, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 60),
        Exercise(name: "Deadlift", category: .back, isTimeBased: false, defaultSets: 4, defaultReps: 6, defaultDurationSeconds: 0, defaultRestSeconds: 120),

        Exercise(name: "Squats", category: .legs, isTimeBased: false, defaultSets: 4, defaultReps: 10, defaultDurationSeconds: 0, defaultRestSeconds: 90),
        Exercise(name: "Lunges", category: .legs, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 60),
        Exercise(name: "Leg Press", category: .legs, isTimeBased: false, defaultSets: 4, defaultReps: 10, defaultDurationSeconds: 0, defaultRestSeconds: 90),
        Exercise(name: "Calf Raises", category: .legs, isTimeBased: false, defaultSets: 3, defaultReps: 15, defaultDurationSeconds: 0, defaultRestSeconds: 45),

        Exercise(name: "Overhead Press", category: .shoulders, isTimeBased: false, defaultSets: 4, defaultReps: 8, defaultDurationSeconds: 0, defaultRestSeconds: 90),
        Exercise(name: "Lateral Raises", category: .shoulders, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 45),
        Exercise(name: "Face Pulls", category: .shoulders, isTimeBased: false, defaultSets: 3, defaultReps: 15, defaultDurationSeconds: 0, defaultRestSeconds: 45),

        Exercise(name: "Bicep Curls", category: .arms, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 45),
        Exercise(name: "Tricep Dips", category: .arms, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 45),
        Exercise(name: "Hammer Curls", category: .arms, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 45),

        Exercise(name: "Plank", category: .core, isTimeBased: true, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 45, defaultRestSeconds: 30),
        Exercise(name: "Crunches", category: .core, isTimeBased: false, defaultSets: 3, defaultReps: 20, defaultDurationSeconds: 0, defaultRestSeconds: 30),
        Exercise(name: "Russian Twists", category: .core, isTimeBased: false, defaultSets: 3, defaultReps: 20, defaultDurationSeconds: 0, defaultRestSeconds: 30),
        Exercise(name: "Mountain Climbers", category: .core, isTimeBased: true, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 30, defaultRestSeconds: 30),

        Exercise(name: "Jumping Jacks", category: .cardio, isTimeBased: true, defaultSets: 3, defaultReps: 0, defaultDurationSeconds: 45, defaultRestSeconds: 20),
        Exercise(name: "Running", category: .cardio, isTimeBased: true, defaultSets: 1, defaultReps: 0, defaultDurationSeconds: 1200, defaultRestSeconds: 0),
        Exercise(name: "Jump Rope", category: .cardio, isTimeBased: true, defaultSets: 4, defaultReps: 0, defaultDurationSeconds: 60, defaultRestSeconds: 30),
        Exercise(name: "Burpees", category: .cardio, isTimeBased: false, defaultSets: 3, defaultReps: 12, defaultDurationSeconds: 0, defaultRestSeconds: 45),

        Exercise(name: "Burpee Circuit", category: .fullBody, isTimeBased: true, defaultSets: 4, defaultReps: 0, defaultDurationSeconds: 40, defaultRestSeconds: 20),
        Exercise(name: "Kettlebell Swings", category: .fullBody, isTimeBased: false, defaultSets: 4, defaultReps: 15, defaultDurationSeconds: 0, defaultRestSeconds: 45),
    ]

    static func grouped() -> [ExerciseGroup] {
        ExerciseCategory.allCases.map { category in
            ExerciseGroup(category: category, exercises: all.filter { $0.category == category })
        }
    }
}

struct ExerciseGroup: Identifiable {
    let category: ExerciseCategory
    let exercises: [Exercise]
    var id: ExerciseCategory { category }
}
