import AVFoundation
import Foundation

/// Calm background music (original ambient loop, Resources/Audio/calm.m4a).
///
/// Plays quietly while the setting is on, fades in/out, and pauses while a workout is in progress. Uses the
/// `.ambient` audio session so it mixes with the user's own music/podcasts and respects the silent switch.
@MainActor
final class CalmMusicPlayer {
    private var player: AVAudioPlayer?
    private let targetVolume: Float = 0.22
    private let fade: TimeInterval = 1.6
    private var wanted = false

    private func makePlayer() -> AVAudioPlayer? {
        if let player { return player }
        guard let url = Bundle.main.url(forResource: "calm", withExtension: "m4a") else { return nil }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0
            p.prepareToPlay()
            player = p
            return p
        } catch {
            return nil
        }
    }

    /// Call whenever the setting, workout state or app activity changes.
    func sync(enabled: Bool, workoutActive: Bool, appActive: Bool = true) {
        wanted = enabled && !workoutActive && appActive
        if wanted {
            guard let p = makePlayer() else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            if !p.isPlaying { p.play() }
            p.setVolume(targetVolume, fadeDuration: fade)
        } else if let p = player, p.isPlaying {
            p.setVolume(0, fadeDuration: fade)
            let delay = UInt64(fade * 1_000_000_000)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: delay)
                guard let self, !self.wanted else { return }
                self.player?.pause()
            }
        }
    }
}
