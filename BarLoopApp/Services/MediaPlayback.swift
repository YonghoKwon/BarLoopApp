import AVFoundation
import BarLoopCore
import Foundation
import MediaPlayer
import Observation

enum PlaybackState: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case ended
    case failed(String)
}

@MainActor
protocol MediaPlaybackControlling: AnyObject {
    var state: PlaybackState { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var rate: Double { get set }
    var volume: Double { get set }

    func play()
    func pause()
    func seek(to seconds: TimeInterval)
}

@MainActor
@Observable
final class LocalMediaPlayerController: MediaPlaybackControlling {
    private(set) var state: PlaybackState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var rate: Double = 1 {
        didSet {
            if player.timeControlStatus == .playing {
                player.rate = Float(rate)
            }
        }
    }
    var volume: Double = 0.85 {
        didSet { player.volume = Float(max(0, min(1, volume))) }
    }

    let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private(set) var loadedItem: LocalMediaItem?

    init() {
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        player.allowsExternalPlayback = true
        player.preventsDisplaySleepDuringVideoPlayback = true
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                currentTime = time.seconds.isFinite ? max(0, time.seconds) : 0
                if player.timeControlStatus == .playing { state = .playing }
            }
        }
        configureRemoteCommands()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func load(_ item: LocalMediaItem) async {
        state = .loading
        pause()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        let asset = AVURLAsset(url: item.url)
        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else { throw MediaPlaybackError.notPlayable }
            let assetDuration = try await asset.load(.duration)
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.audioTimePitchAlgorithm = .timeDomain
            player.replaceCurrentItem(with: playerItem)
            loadedItem = item
            duration = max(0, assetDuration.seconds.isFinite ? assetDuration.seconds : 0)
            currentTime = 0
            player.volume = Float(volume)
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.state = .ended }
            }
            updateNowPlaying()
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func play() {
        guard player.currentItem != nil else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.playImmediately(atRate: Float(rate))
            state = .playing
            updateNowPlaying()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func pause() {
        player.pause()
        if player.currentItem != nil { state = .paused }
        updateNowPlaying()
    }

    func seek(to seconds: TimeInterval) {
        let target = max(0, min(duration > 0 ? duration : seconds, seconds))
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        currentTime = target
        updateNowPlaying()
    }

    private func updateNowPlaying() {
        guard let item = loadedItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item.fileName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? rate : 0,
        ]
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                state == .playing ? pause() : play()
            }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }
}

enum MediaPlaybackError: LocalizedError {
    case notPlayable

    var errorDescription: String? {
        switch self {
        case .notPlayable: String(localized: "media.error.notPlayable")
        }
    }
}
