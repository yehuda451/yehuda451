import Foundation
import Combine
import AudioToolbox
import UIKit

enum WorkoutPhase {
    case work
    case rest
    case finished
}

/// Drives a single active-workout session: walks through each exercise's
/// sets, alternating a work timer and a rest timer, with haptic + sound
/// cues on every phase change.
final class WorkoutTimerManager: ObservableObject {
    @Published private(set) var exercises: [SessionExercise]
    @Published private(set) var exerciseIndex: Int = 0
    @Published private(set) var setIndex: Int = 0
    @Published private(set) var phase: WorkoutPhase = .work
    @Published private(set) var secondsRemaining: Int = 0
    @Published private(set) var isRunning: Bool = false

    private var timerCancellable: AnyCancellable?
    private let startedAt = Date()

    init(exercises: [SessionExercise]) {
        self.exercises = exercises.sorted { $0.order < $1.order }
    }

    var currentExercise: SessionExercise? {
        guard exercises.indices.contains(exerciseIndex) else { return nil }
        return exercises[exerciseIndex]
    }

    var totalExercises: Int { exercises.count }

    var progress: Double {
        guard !exercises.isEmpty else { return 1 }
        return Double(exerciseIndex) / Double(exercises.count)
    }

    var elapsedMinutes: Int {
        Int(Date().timeIntervalSince(startedAt) / 60)
    }

    func start() {
        guard phase != .finished else { return }
        if secondsRemaining == 0 { secondsRemaining = currentPhaseDuration() }
        isRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        timerCancellable?.cancel()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// Skips whatever is currently happening (work or rest) and advances.
    func skip() {
        advance()
    }

    private func tick() {
        guard secondsRemaining > 0 else {
            advance()
            return
        }
        secondsRemaining -= 1
        if secondsRemaining == 0 {
            advance()
        }
    }

    private func currentPhaseDuration() -> Int {
        guard let exercise = currentExercise else { return 0 }
        switch phase {
        case .work:
            return exercise.isTimeBased ? exercise.durationSeconds : max(exercise.reps, 1) * 3
        case .rest:
            return exercise.restSeconds
        case .finished:
            return 0
        }
    }

    /// Moves from work -> rest -> next set -> next exercise -> finished.
    private func advance() {
        guard let exercise = currentExercise else {
            finish()
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlaySystemSound(1057)

        switch phase {
        case .work:
            if exercise.restSeconds > 0 {
                phase = .rest
                secondsRemaining = exercise.restSeconds
            } else {
                advanceSetOrExercise(exercise)
            }
        case .rest:
            advanceSetOrExercise(exercise)
        case .finished:
            break
        }
    }

    private func advanceSetOrExercise(_ exercise: SessionExercise) {
        if setIndex + 1 < exercise.sets {
            setIndex += 1
            phase = .work
            secondsRemaining = currentPhaseDuration()
        } else {
            setIndex = 0
            exerciseIndex += 1
            if exerciseIndex >= exercises.count {
                finish()
            } else {
                phase = .work
                secondsRemaining = currentPhaseDuration()
            }
        }
    }

    private func finish() {
        phase = .finished
        isRunning = false
        timerCancellable?.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
