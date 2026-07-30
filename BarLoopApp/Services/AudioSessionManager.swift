import AVFAudio
import Foundation
import Observation

@MainActor
@Observable
final class AudioSessionManager {
    enum State: Equatable {
        case idle
        case active
        case interrupted
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var currentRoute = ""
    var onInterruptionEnded: (() -> Void)?
    var onRouteChanged: (() -> Void)?

    private let session = AVAudioSession.sharedInstance()
    private var observers: [NSObjectProtocol] = []

    init() {
        currentRoute = routeDescription
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                currentRoute = routeDescription
                onRouteChanged?()
            }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func activate() throws {
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            currentRoute = routeDescription
            state = .active
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        state = .idle
    }

    private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            state = .interrupted
            return
        }
        do {
            try activate()
            onInterruptionEnded?()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private var routeDescription: String {
        let names = session.currentRoute.outputs.map(\.portName)
        return names.isEmpty ? String(localized: "audio.route.default") : names.joined(separator: ", ")
    }
}

