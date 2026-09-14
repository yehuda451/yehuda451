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

    private init() {
        tickPlayer = Self.loadPlayer(named: "tick")
        chimePlayer = Self.loadPlayer(named: "chime")
        configureAudioSession()
    }

    private static func loadPlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    /// `.mixWithOthers` is what keeps another app's music playing instead of
    /// being stopped; done once, up front, rather than lazily right before a
    /// sound plays, so there's no race with music that's already active.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    /// A short beep for each of the final seconds of a work/rest period.
    func playTick() {
        tickPlayer?.currentTime = 0
        tickPlayer?.play()
    }

    /// A distinct chime marking a work/rest transition, a new set, or a new exercise.
    func playChime() {
        chimePlayer?.currentTime = 0
        chimePlayer?.play()
    }
}
