import Foundation
import Combine
import UIKit

enum WorkoutPhase {
    case work
    case rest
    case finished
}

/// Drives a single active-workout session: walks through each exercise's
/// sets, alternating a work timer and a rest timer, with haptic + sound
/// cues on every phase change.
///
/// The countdown is anchored to a wall-clock end date rather than a simple
/// decrementing counter. A repeating `Timer` doesn't fire while the app is
/// suspended in the background, so a counter-based countdown would freeze
/// while the app is backgrounded and only resume once reopened. Anchoring to
/// a real `Date` means the very next tick (or an explicit `refresh()` when
/// the app returns to the foreground) snaps the display back to the correct
/// remaining time.
final class WorkoutTimerManager: ObservableObject {
    @Published private(set) var exercises: [SessionExercise]
    @Published private(set) var exerciseIndex: Int = 0
    @Published private(set) var setIndex: Int = 0
    @Published private(set) var phase: WorkoutPhase = .work
    @Published private(set) var secondsRemaining: Int = 0
    @Published private(set) var isRunning: Bool = false

    private var timerCancellable: AnyCancellable?
    private var phaseEndDate = Date()
    private let startedAt = Date()

    /// How many of the final seconds of a phase get a countdown beep.
    private let countdownWindow = 3

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
        phaseEndDate = Date().addingTimeInterval(TimeInterval(secondsRemaining))
        isRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        secondsRemaining = max(0, Int(ceil(phaseEndDate.timeIntervalSinceNow)))
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

    /// Re-syncs the displayed countdown to the wall clock. Call this when
    /// the app returns to the foreground so the display doesn't wait for the
    /// next natural timer tick to catch up.
    func refresh() {
        guard isRunning else { return }
        tick()
    }

    private func tick() {
        guard isRunning, phase != .finished else { return }

        var remaining = Int(ceil(phaseEndDate.timeIntervalSinceNow))
        while remaining <= 0 {
            advance()
            guard phase != .finished else { return }
            remaining = Int(ceil(phaseEndDate.timeIntervalSinceNow))
        }

        if remaining <= countdownWindow && remaining < secondsRemaining {
            WorkoutSoundManager.shared.playTick()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        secondsRemaining = remaining
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

    private func setPhaseDuration(_ duration: Int) {
        secondsRemaining = duration
        phaseEndDate = Date().addingTimeInterval(TimeInterval(duration))
    }

    /// Moves from work -> rest -> next set -> next exercise -> finished.
    private func advance() {
        guard let exercise = currentExercise else {
            finish()
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        WorkoutSoundManager.shared.playChime()

        switch phase {
        case .work:
            if exercise.restSeconds > 0 {
                phase = .rest
                setPhaseDuration(exercise.restSeconds)
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
            setPhaseDuration(currentPhaseDuration())
        } else {
            setIndex = 0
            exerciseIndex += 1
            if exerciseIndex >= exercises.count {
                finish()
            } else {
                phase = .work
                setPhaseDuration(currentPhaseDuration())
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
