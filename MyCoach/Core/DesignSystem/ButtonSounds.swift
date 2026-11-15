import AudioToolbox
import SwiftUI

/// Plays the designated button sounds (see `ButtonSound`). System sounds give instant playback and respect
/// the silent switch.
@MainActor
enum ButtonSounds {
    static var enabled = true
    private static var ids: [ButtonSound: SystemSoundID] = [:]
    private static var lastPlayed = Date.distantPast
    /// A screen button that also switches tabs shouldn't play two sounds at once.
    private static let overlapGuard: TimeInterval = 0.15

    static func play(_ sound: ButtonSound) {
        guard enabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPlayed) > overlapGuard else { return }
        lastPlayed = now
        if let id = soundID(for: sound) {
            AudioServicesPlaySystemSound(id)
        }
    }

    /// Longer Workout Complete effects (Resources/Audio/Effects, from Scripts/make_effect_sounds.py).
    enum Effect: String {
        case celebration, whoosh, fire
    }

    private static var effectIDs: [Effect: SystemSoundID] = [:]

    /// Plays a celebration effect; respects the same Settings toggle as button sounds.
    static func play(effect: Effect) {
        guard enabled else { return }
        if effectIDs[effect] == nil {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { return }
            var id: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else { return }
            effectIDs[effect] = id
        }
        if let id = effectIDs[effect] { AudioServicesPlaySystemSound(id) }
    }

    private static func soundID(for sound: ButtonSound) -> SystemSoundID? {
        if let id = ids[sound] { return id }
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: "wav") else { return nil }
        var id: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else { return nil }
        ids[sound] = id
        return id
    }
}

// MARK: - Which sound the current screen uses

private struct ButtonSoundKey: EnvironmentKey {
    static let defaultValue: ButtonSound = .today
}

extension EnvironmentValues {
    /// Set per tab in MainTabView (and to `.onboarding` during setup); buttons read it.
    var buttonSound: ButtonSound {
        get { self[ButtonSoundKey.self] }
        set { self[ButtonSoundKey.self] = newValue }
    }
}

// MARK: - Button styles that play the screen's sound

/// Default-looking button that plays the screen's designated sound.
struct SoundButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SoundButton(configuration: configuration, plain: false)
    }
}

/// `.plain`-looking button that plays the screen's designated sound.
struct SoundPlainButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SoundButton(configuration: configuration, plain: true)
    }
}

private struct SoundButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let plain: Bool
    @Environment(\.buttonSound) private var sound

    var body: some View {
        let button = Button(role: configuration.role) {
            ButtonSounds.play(sound)
            configuration.trigger()
        } label: {
            configuration.label
        }
        if plain {
            button.buttonStyle(.plain)
        } else {
            button.buttonStyle(.automatic)
        }
    }
}

extension View {
    /// Tags a screen with its designated button sound and makes its buttons play it.
    func buttonSound(_ sound: ButtonSound) -> some View {
        environment(\.buttonSound, sound).buttonStyle(SoundButtonStyle())
    }
}
