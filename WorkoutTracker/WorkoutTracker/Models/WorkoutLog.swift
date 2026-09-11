import Foundation
import SwiftData

/// A record that the user completed a given session on a given calendar day.
@Model
final class WorkoutLog {
    var id: UUID
    var date: Date
    var sessionName: String
    var sessionID: UUID?
    var symbolName: String
    var colorHex: String
    var durationMinutes: Int
    var exercisesCompleted: Int
    var totalExercises: Int
    var notes: String

    init(date: Date, sessionName: String, sessionID: UUID?, symbolName: String, colorHex: String, durationMinutes: Int, exercisesCompleted: Int, totalExercises: Int, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.sessionName = sessionName
        self.sessionID = sessionID
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.durationMinutes = durationMinutes
        self.exercisesCompleted = exercisesCompleted
        self.totalExercises = totalExercises
        self.notes = notes
    }

    var dayStart: Date {
        Calendar.current.startOfDay(for: date)
    }
}
