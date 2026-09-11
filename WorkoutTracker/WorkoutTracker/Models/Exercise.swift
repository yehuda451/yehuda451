import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case cardio = "Cardio"
    case fullBody = "Full Body"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .legs: return "figure.squat"
        case .shoulders: return "figure.arms.open"
        case .arms: return "dumbbell.fill"
        case .core: return "figure.core.training"
        case .cardio: return "figure.run"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
}

/// A reusable exercise definition, either from the built-in library or user-created.
struct Exercise: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: ExerciseCategory
    var isTimeBased: Bool
    var defaultSets: Int
    var defaultReps: Int
    var defaultDurationSeconds: Int
    var defaultRestSeconds: Int
}
