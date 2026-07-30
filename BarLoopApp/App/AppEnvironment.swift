import BarLoopCore
import Observation
import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    let settings = SettingsStore()
    let audioSession: AudioSessionManager
    let metronome: MetronomeEngine
    let mediaLibrary = LocalMediaLibrary()
    let localPlayer = LocalMediaPlayerController()
    let youtubePlayer = YouTubePlayerController()
    let midi = MIDIManager()

    var appearance: AppAppearance {
        get { settings.appearance }
        set { settings.appearance = newValue }
    }

    init() {
        let session = AudioSessionManager()
        audioSession = session
        metronome = MetronomeEngine(audioSession: session)
    }

    func prepare() async {
        await mediaLibrary.refresh()
        midi.start()
        midi.onAction = { [weak self] action in
            guard self != nil else { return }
            NotificationCenter.default.post(name: action.notificationName, object: nil)
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension MIDIAction {
    var notificationName: Notification.Name {
        switch self {
        case .togglePlayback: .barLoopTogglePlayback
        case .previousSection: .barLoopPreviousSection
        case .restartLoop: .barLoopRestartLoop
        case .nextSection: .barLoopNextSection
        }
    }
}

extension Notification.Name {
    static let barLoopTogglePlayback = Notification.Name("barloop.togglePlayback")
    static let barLoopPreviousSection = Notification.Name("barloop.previousSection")
    static let barLoopRestartLoop = Notification.Name("barloop.restartLoop")
    static let barLoopNextSection = Notification.Name("barloop.nextSection")
}
