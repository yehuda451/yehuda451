import Foundation
import AVFoundation

/// Plays short audio cues during an active workout — a tick for the final
/// countdown seconds and a chime on every phase change — configured to mix
/// with any music already playing and to work even if the phone is muted,
/// like any other workout/timer app.
final class WorkoutSoundManager {
    static let shared = WorkoutSoundManager()

    private var tickPlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?
    private var sessionIsActive = false

    private init() {
        tickPlayer = Self.loadPlayer(named: "tick")
        chimePlayer = Self.loadPlayer(named: "chime")
    }

    private static func loadPlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    private func activateSessionIfNeeded() {
        guard !sessionIsActive else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
        try? session.setActive(true)
        sessionIsActive = true
    }

    /// A short beep for each of the final seconds of a work/rest period.
    func playTick() {
        activateSessionIfNeeded()
        tickPlayer?.currentTime = 0
        tickPlayer?.play()
    }

    /// A distinct chime marking a work/rest transition, a new set, or a new exercise.
    func playChime() {
        activateSessionIfNeeded()
        chimePlayer?.currentTime = 0
        chimePlayer?.play()
    }
}
