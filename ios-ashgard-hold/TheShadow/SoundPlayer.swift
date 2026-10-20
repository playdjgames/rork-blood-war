//
//  SoundPlayer.swift
//  TheShadow
//
//  Blood War — short game sound effects using built-in iOS system sounds
//  (no bundled audio). Every play call checks `bw.soundEnabled` first.
//

import AudioToolbox
import Foundation

/// Plays the game's sound effects. Silenced when `bw.soundEnabled` is false.
final class SoundPlayer {
    static let shared = SoundPlayer()

    /// UserDefaults key for the sound toggle; missing means on.
    static let enabledKey = "bw.soundEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Sound on/off, default true.
    var isEnabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    /// The inverse of `isEnabled`, same `bw.soundEnabled` key.
    var isMuted: Bool {
        get { !isEnabled }
        set { isEnabled = !newValue }
    }

    /// iOS system sound IDs, each one distinct.
    private enum Effect: SystemSoundID {
        case collect = 1057 // light "tink"
        case train = 1104   // short wooden tock
        case march = 1001   // whoosh — a march sets out
        case combat = 1033  // telegraph rattle
        case upgrade = 1025 // fanfare
    }

    func playCollect() { play(.collect) }
    func playTrain() { play(.train) }
    func playMarch() { play(.march) }
    func playCombat() { play(.combat) }
    func playUpgrade() { play(.upgrade) }

    private func play(_ effect: Effect) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(effect.rawValue)
    }
}
