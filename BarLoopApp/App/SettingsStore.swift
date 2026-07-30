import BarLoopCore
import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private enum Key {
        static let practice = "barloop.ios.practice.v1"
        static let metronome = "barloop.ios.metronome.v1"
        static let trainer = "barloop.ios.trainer.v1"
        static let appearance = "barloop.ios.appearance"
        static let keepAwake = "barloop.ios.keepAwake"
        static let countMode = "barloop.ios.countMode"
    }

    var practice: PracticeSettings {
        didSet { save(practice, key: Key.practice) }
    }
    var metronome: MetronomeSettings {
        didSet { save(metronome, key: Key.metronome) }
    }
    var tempoTrainer: TempoTrainerSettings {
        didSet { save(tempoTrainer, key: Key.trainer) }
    }
    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    var keepAwake: Bool {
        didSet { defaults.set(keepAwake, forKey: Key.keepAwake) }
    }
    var countMode: CountMode {
        didSet { defaults.set(countMode.rawValue, forKey: Key.countMode) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        practice = Self.decode(PracticeSettings.self, key: Key.practice, defaults: defaults) ?? .init()
        metronome = Self.decode(MetronomeSettings.self, key: Key.metronome, defaults: defaults) ?? .init()
        tempoTrainer = Self.decode(TempoTrainerSettings.self, key: Key.trainer, defaults: defaults) ?? .init()
        appearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        keepAwake = defaults.object(forKey: Key.keepAwake) as? Bool ?? true
        countMode = CountMode(rawValue: defaults.string(forKey: Key.countMode) ?? "") ?? .click
    }

    func apply(_ backup: BarLoopBackup) {
        practice = backup.practiceSettings
        metronome = backup.metronomeSettings
        tempoTrainer = backup.tempoTrainerSettings
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        key: String,
        defaults: UserDefaults
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
