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
        restartTicking()
        scheduleUpcomingNotification()
    }

    func pause() {
        secondsRemaining = max(0, Int(ceil(phaseEndDate.timeIntervalSinceNow)))
        isRunning = false
        timerCancellable?.cancel()
        NotificationManager.shared.cancelPhaseEnd()
    }

    deinit {
        NotificationManager.shared.cancelPhaseEnd()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    /// Skips whatever is currently happening (work or rest) and advances.
    func skip() {
        advance()
    }

    /// Re-syncs the displayed countdown to the wall clock and re-establishes
    /// the periodic tick. Call this when the app returns to the foreground:
    /// a suspended app gets no run-loop time at all, and a `Timer` scheduled
    /// before suspension isn't guaranteed to resume firing reliably once the
    /// app wakes back up, which otherwise leaves the countdown stuck at
    /// whatever it last showed with no further cues or phase changes.
    func refresh() {
        guard isRunning else { return }
        tick()
        if isRunning {
            restartTicking()
        }
    }

    private func restartTicking() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
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
        if isRunning {
            scheduleUpcomingNotification()
        }
    }

    /// Schedules a local notification for when the current phase ends, so
    /// you're told even if you're still in another app when it happens.
    private func scheduleUpcomingNotification() {
        guard let exercise = currentExercise else {
            NotificationManager.shared.cancelPhaseEnd()
            return
        }
        let title: String
        let body: String
        switch phase {
        case .work:
            title = "Work interval done"
            body = exercise.restSeconds > 0 ? "Rest time" : "Next set — \(exercise.exerciseName)"
        case .rest:
            title = "Rest over"
            body = "Back to \(exercise.exerciseName)"
        case .finished:
            NotificationManager.shared.cancelPhaseEnd()
            return
        }
        NotificationManager.shared.schedulePhaseEnd(in: secondsRemaining, title: title, body: body)
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
        NotificationManager.shared.cancelPhaseEnd()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
