import BarLoopCore
import Foundation
import Observation
import UIKit

enum PracticeSourceMode: String, CaseIterable, Identifiable {
    case local
    case youtube
    var id: String { rawValue }
}

@MainActor
@Observable
final class PracticeController {
    var sourceMode: PracticeSourceMode = .local
    var selectedLocalItem: LocalMediaItem?
    var youtubeInput = ""
    private(set) var youtubeVideoID: String?
    var loop: LoopDefinition = .time(start: 0, end: 8)
    private(set) var bars: [BarSegment] = []
    private(set) var loopCount = 0
    private(set) var waveform: [Float] = []
    private(set) var tapCount = 0
    private(set) var trainerCurrentBPM: Int?
    private(set) var trainerRepeatAtStep = 0
    private(set) var countInBeatsRemaining = 0
    var notice: String?

    let environment: AppEnvironment
    private var loopTimer: Timer?
    private var tapTimes: [TimeInterval] = []
    private var playbackTask: Task<Void, Never>?
    private var trainerRestTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.environment = environment
        registerRemoteCommands()
    }

    var player: (any MediaPlaybackControlling)? {
        switch sourceMode {
        case .local:
            selectedLocalItem == nil ? nil : environment.localPlayer
        case .youtube:
            youtubeVideoID == nil ? nil : environment.youtubePlayer
        }
    }

    var state: PlaybackState { player?.state ?? .idle }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }
    var settings: PracticeSettings {
        get { environment.settings.practice }
        set {
            environment.settings.practice = newValue
            player?.rate = newValue.playbackRate
            player?.volume = newValue.mediaVolume
            rebuildBars()
        }
    }

    var trainerSettings: TempoTrainerSettings {
        get { environment.settings.tempoTrainer }
        set {
            environment.settings.tempoTrainer = newValue
            if !newValue.enabled {
                trainerCurrentBPM = nil
                trainerRepeatAtStep = 0
            }
        }
    }

    func select(_ item: LocalMediaItem) async {
        pause()
        sourceMode = .local
        selectedLocalItem = item
        await environment.localPlayer.load(item)
        player?.rate = settings.playbackRate
        player?.volume = settings.mediaVolume
        rebuildBars()
        waveform = (try? await WaveformAnalyzer.analyze(url: item.url)) ?? []
        resetLoopToMedia()
    }

    func loadYouTube() {
        guard let id = PracticeMath.extractYouTubeID(youtubeInput) else {
            notice = String(localized: "youtube.error.invalid")
            return
        }
        pause()
        sourceMode = .youtube
        youtubeVideoID = id
        environment.youtubePlayer.load(videoID: id)
        environment.youtubePlayer.rate = settings.playbackRate
        environment.youtubePlayer.volume = settings.mediaVolume
        waveform = []
        loop = .time(start: 0, end: 8)
    }

    func togglePlayback() {
        state == .playing ? pause() : play()
    }

    func play() {
        guard let player else { return }
        playbackTask?.cancel()
        if settings.keepAwake(environment: environment) {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        playbackTask = Task { [weak self] in
            guard let self else { return }
            if trainerSettings.enabled, trainerCurrentBPM == nil {
                trainerCurrentBPM = PracticeMath.clampBPM(Double(trainerSettings.startBPM))
                applyTrainerBPM()
            }
            configurePracticeMetronome()
            let countInBeats = settings.countInBars * settings.beatsPerBar
            if countInBeats > 0 {
                countInBeatsRemaining = countInBeats
                environment.metronome.start()
                for remaining in stride(from: countInBeats, through: 1, by: -1) {
                    countInBeatsRemaining = remaining
                    try? await Task.sleep(for: .seconds(60 / Double(settings.bpm)))
                    guard !Task.isCancelled else { return }
                }
                countInBeatsRemaining = 0
                environment.metronome.stop()
            }
            let bounds = loopBounds
            let preRoll = Double(settings.preRollBeats) * 60 / Double(settings.bpm)
            player.seek(to: max(0, bounds.start - preRoll))
            let offset = settings.syncOffsetMilliseconds
            if settings.metronomeEnabled, offset <= 0 {
                environment.metronome.start()
                if offset < 0 {
                    try? await Task.sleep(for: .milliseconds(abs(offset)))
                    guard !Task.isCancelled else { return }
                }
                player.play()
            } else {
                player.play()
                if settings.metronomeEnabled {
                    try? await Task.sleep(for: .milliseconds(offset))
                    guard !Task.isCancelled else { return }
                    environment.metronome.start()
                }
            }
            startLoopMonitor()
        }
    }

    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        trainerRestTask?.cancel()
        trainerRestTask = nil
        player?.pause()
        environment.metronome.stop()
        loopTimer?.invalidate()
        loopTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: time)
    }

    func restartLoop() {
        player?.seek(to: loopBounds.start)
    }

    func quickLoop(grooveBars: Int, fillBars: Int = 1) {
        guard !bars.isEmpty else { return }
        let total = grooveBars + fillBars
        loop = .bars(start: 0, end: min(bars.count - 1, total - 1))
        restartLoop()
    }

    func setTimeLoop(start: TimeInterval, end: TimeInterval) {
        let safeStart = max(0, min(start, duration))
        let safeEnd = max(safeStart + 0.1, min(end, duration > 0 ? duration : end))
        loop = .time(start: safeStart, end: safeEnd)
    }

    func setBarLoop(start: Int, end: Int) {
        guard !bars.isEmpty else { return }
        let safeStart = max(0, min(start, bars.count - 1))
        let safeEnd = max(safeStart, min(end, bars.count - 1))
        loop = .bars(start: safeStart, end: safeEnd)
    }

    func tapTempo(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if let last = tapTimes.last, now - last > 2 { tapTimes.removeAll() }
        tapTimes.append(now)
        tapTimes = Array(tapTimes.suffix(8))
        tapCount = tapTimes.count
        guard tapTimes.count >= 2 else { return }
        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { next, previous in next - previous }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        guard average > 0 else { return }
        settings.bpm = PracticeMath.clampBPM(60 / average)
    }

    func rebuildBars() {
        bars = PracticeMath.generateBars(
            duration: duration,
            bpm: Double(settings.bpm),
            beatsPerBar: settings.beatsPerBar,
            firstDownbeat: settings.firstDownbeat
        )
    }

    private var loopBounds: (start: TimeInterval, end: TimeInterval) {
        switch loop {
        case let .time(start, end):
            return (start, end)
        case let .bars(start, end):
            guard let first = bars[safe: start], let last = bars[safe: end] else { return (0, duration) }
            return (first.start, last.end)
        }
    }

    private func startLoopMonitor() {
        loopTimer?.invalidate()
        loopTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      settings.loopEnabled,
                      state == .playing else { return }
                let bounds = loopBounds
                if currentTime >= bounds.end - 0.018 {
                    handleLoopBoundary(bounds: bounds)
                }
                if bars.isEmpty, duration > 0 { rebuildBars() }
            }
        }
    }

    private func handleLoopBoundary(bounds: (start: TimeInterval, end: TimeInterval)) {
        loopCount += 1
        trainerRepeatAtStep += 1
        let preRoll = Double(settings.preRollBeats) * 60 / Double(settings.bpm)
        let destination = max(0, bounds.start - preRoll)

        if trainerSettings.enabled,
           trainerRepeatAtStep >= max(1, trainerSettings.repeatsPerStep),
           (trainerCurrentBPM ?? settings.bpm) < trainerSettings.targetBPM {
            trainerRepeatAtStep = 0
            trainerCurrentBPM = min(
                trainerSettings.targetBPM,
                (trainerCurrentBPM ?? settings.bpm) + max(1, trainerSettings.stepBPM)
            )
            applyTrainerBPM()
            if trainerSettings.restSeconds > 0 {
                player?.pause()
                environment.metronome.stop()
                trainerRestTask?.cancel()
                trainerRestTask = Task { [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(for: .seconds(trainerSettings.restSeconds))
                    guard !Task.isCancelled else { return }
                    player?.seek(to: destination)
                    configurePracticeMetronome()
                    if settings.metronomeEnabled { environment.metronome.start() }
                    player?.play()
                }
                return
            }
        }

        player?.seek(to: destination)
        if settings.metronomeEnabled {
            environment.metronome.stop()
            configurePracticeMetronome()
            environment.metronome.start()
        }
    }

    private func applyTrainerBPM() {
        guard let bpm = trainerCurrentBPM else { return }
        var value = settings
        value.bpm = bpm
        settings = value
    }

    private func configurePracticeMetronome() {
        environment.metronome.drumPattern = nil
        environment.metronome.settings = .init(
            bpm: settings.bpm,
            beatsPerBar: settings.beatsPerBar,
            subdivision: settings.subdivision,
            volume: settings.metronomeVolume,
            accents: (0..<settings.beatsPerBar).map { $0 == 0 }
        )
        environment.metronome.countMode = environment.settings.countMode
    }

    private func resetLoopToMedia() {
        let end = min(8, duration)
        loop = .time(start: 0, end: max(0.1, end))
        loopCount = 0
    }

    private func registerRemoteCommands() {
        NotificationCenter.default.addObserver(
            forName: .barLoopTogglePlayback,
            object: nil,
            queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.togglePlayback() } }
        NotificationCenter.default.addObserver(
            forName: .barLoopRestartLoop,
            object: nil,
            queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.restartLoop() } }
    }
}

private extension PracticeSettings {
    func keepAwake(environment: AppEnvironment) -> Bool {
        environment.settings.keepAwake
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
