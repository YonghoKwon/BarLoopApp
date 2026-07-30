import AVFAudio
import BarLoopCore
import Darwin
import Foundation
import Observation

struct MetronomeTick: Equatable, Sendable {
    let beatInBar: Int
    let subdivisionInBeat: Int
    let barIndex: Int
    let audible: Bool
}

@MainActor
@Observable
final class MetronomeEngine {
    enum State: Equatable {
        case idle, starting, running, interrupted
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var tick = MetronomeTick(beatInBar: 0, subdivisionInBeat: 0, barIndex: 0, audible: true)
    private(set) var elapsedBars = 0
    var settings = MetronomeSettings() {
        didSet { clickBuffers.removeAll() }
    }
    var countMode: CountMode = .click
    var drumPattern: DrumPattern? {
        didSet { drumBuffers.removeAll() }
    }
    var movingAccentStep: Int?
    var onTick: ((MetronomeTick) -> Void)?

    private let audioSession: AudioSessionManager
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let speech = AVSpeechSynthesizer()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var timer: DispatchSourceTimer?
    private var nextHostTime: UInt64 = 0
    private var stepIndex = 0
    private var clickBuffers: [ClickKey: AVAudioPCMBuffer] = [:]
    private var drumBuffers: [DrumKey: AVAudioPCMBuffer] = [:]

    init(audioSession: AudioSessionManager) {
        self.audioSession = audioSession
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        audioSession.onInterruptionEnded = { [weak self] in self?.resumeAfterInterruption() }
        audioSession.onRouteChanged = { [weak self] in self?.resynchronize() }
    }

    func start() {
        guard state != .running else { return }
        state = .starting
        do {
            try audioSession.activate()
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
            if !player.isPlaying { player.play() }
            stepIndex = 0
            elapsedBars = 0
            nextHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.08)
            state = .running
            startScheduler()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        player.stop()
        speech.stopSpeaking(at: .immediate)
        state = .idle
        stepIndex = 0
        elapsedBars = 0
    }

    func toggle() {
        state == .running ? stop() : start()
    }

    func playTestClick(accent: Bool = true) {
        do {
            try audioSession.activate()
            if !engine.isRunning { try engine.start() }
            if !player.isPlaying { player.play() }
            player.scheduleBuffer(buffer(accent: accent, subdivision: false), at: nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func startScheduler() {
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.scheduleAhead() }
        self.timer = timer
        timer.resume()
    }

    private func scheduleAhead() {
        guard state == .running else { return }
        let now = mach_absolute_time()
        let ahead = now + AVAudioTime.hostTime(forSeconds: 0.14)
        if nextHostTime < now || nextHostTime > now + AVAudioTime.hostTime(forSeconds: 1) {
            nextHostTime = now + AVAudioTime.hostTime(forSeconds: 0.06)
        }
        var scheduled = 0
        while nextHostTime < ahead, scheduled < 128 {
            scheduleStep(at: nextHostTime, index: stepIndex)
            let seconds = MetronomeMath.interval(
                bpm: settings.bpm,
                subdivision: settings.subdivision,
                swing: settings.swing,
                stepIndex: stepIndex
            )
            nextHostTime += AVAudioTime.hostTime(forSeconds: seconds)
            stepIndex += 1
            scheduled += 1
        }
    }

    private func scheduleStep(at hostTime: UInt64, index: Int) {
        let subdivision = settings.subdivision.rawValue
        let subdivisionInBeat = index % subdivision
        let absoluteBeat = index / subdivision
        let beat = absoluteBeat % settings.beatsPerBar
        let bar = absoluteBeat / settings.beatsPerBar
        let audible = MetronomeMath.isBarAudible(
            barIndex: bar,
            gapEnabled: settings.gapEnabled,
            playBars: settings.gapPlayBars,
            muteBars: settings.gapMuteBars
        )
        let stepInBar = beat * 4 + min(3, Int(Double(subdivisionInBeat) * 4 / Double(subdivision)))
        let movingAccent = stepInBar == movingAccentStep
        let accent = movingAccent || (subdivisionInBeat == 0 && settings.accents[safe: beat] == true)
        if audible {
            let patternSounded = schedulePatternIfNeeded(
                at: hostTime,
                stepInBar: stepInBar,
                movingAccent: movingAccent
            )
            if countMode != .voice, (!patternSounded || subdivisionInBeat == 0) {
                player.scheduleBuffer(
                    buffer(accent: accent, subdivision: subdivisionInBeat != 0),
                    at: AVAudioTime(hostTime: hostTime)
                )
            }
        }
        let now = mach_absolute_time()
        let delay = max(0, AVAudioTime.seconds(forHostTime: hostTime > now ? hostTime - now : 0))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, state == .running else { return }
            let value = MetronomeTick(
                beatInBar: beat,
                subdivisionInBeat: subdivisionInBeat,
                barIndex: bar,
                audible: audible
            )
            tick = value
            elapsedBars = bar
            if audible, subdivisionInBeat == 0, countMode != .click {
                speakBeat(beat)
            }
            if settings.autoTempoBars > 0,
               beat == 0,
               subdivisionInBeat == 0,
               bar > 0,
               bar.isMultiple(of: settings.autoTempoBars) {
                settings.bpm = PracticeMath.clampBPM(Double(settings.bpm + settings.autoTempoStep))
            }
            onTick?(value)
        }
    }

    private func schedulePatternIfNeeded(
        at hostTime: UInt64,
        stepInBar: Int,
        movingAccent: Bool
    ) -> Bool {
        guard settings.subdivision == .sixteenth,
              let pattern,
              stepInBar < pattern.stepCount else { return false }
        var sounded = false
        for instrument in DrumInstrument.allCases {
            let level = pattern.steps[instrument]?[safe: stepInBar] ?? .off
            guard level != .off else { continue }
            sounded = true
            let effectiveLevel: DrumStepLevel = movingAccent ? .accent : level
            player.scheduleBuffer(
                drumBuffer(instrument: instrument, level: effectiveLevel),
                at: AVAudioTime(hostTime: hostTime)
            )
        }
        return sounded
    }

    private func buffer(accent: Bool, subdivision: Bool) -> AVAudioPCMBuffer {
        let key = ClickKey(sound: accent ? settings.accentSound : settings.sound, accent: accent, subdivision: subdivision)
        if let cached = clickBuffers[key] { return cached }
        let duration = subdivision ? 0.022 : 0.045
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        result.frameLength = frames
        let frequency = frequency(for: key.sound, accent: accent)
        let volume = subdivision ? settings.subdivisionVolume : (accent ? settings.accentVolume : settings.volume)
        if let channel = result.floatChannelData?[0] {
            for frame in 0..<Int(frames) {
                let time = Double(frame) / format.sampleRate
                let envelope = exp(-time * (subdivision ? 110 : 70))
                let fundamental = sin(2 * .pi * frequency * time)
                let overtone = sin(2 * .pi * frequency * 2.03 * time) * 0.24
                channel[frame] = Float((fundamental + overtone) * envelope * volume)
            }
        }
        clickBuffers[key] = result
        return result
    }

    private func frequency(for sound: ClickSound, accent: Bool) -> Double {
        let base: Double = switch sound {
        case .classic: 1_250
        case .wood: 820
        case .rim: 1_720
        case .cowbell: 640
        case .digital: 2_100
        case .clave: 1_480
        case .shaker: 3_100
        case .low: 390
        }
        return accent ? base * 1.22 : base
    }

    private func drumBuffer(instrument: DrumInstrument, level: DrumStepLevel) -> AVAudioPCMBuffer {
        let key = DrumKey(instrument: instrument, level: level)
        if let cached = drumBuffers[key] { return cached }
        let duration: Double = instrument == .kick ? 0.11 : (instrument == .hihat ? 0.035 : 0.075)
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        result.frameLength = frames
        let frequency: Double = switch instrument {
        case .kick: 78
        case .snare: 210
        case .floorTom: 125
        case .midTom: 165
        case .rackTom: 230
        case .hihat: 4_800
        case .ride: 2_700
        case .crash: 3_400
        }
        let gain = level == .accent ? 0.75 : 0.45
        if let channel = result.floatChannelData?[0] {
            for frame in 0..<Int(frames) {
                let time = Double(frame) / format.sampleRate
                let decay = instrument == .kick ? 30.0 : (instrument == .hihat ? 120 : 55)
                let envelope = exp(-time * decay)
                let noise = Double.random(in: -1...1)
                let tonal = sin(2 * .pi * frequency * time)
                let mix = [.hihat, .ride, .crash, .snare].contains(instrument)
                    ? tonal * 0.35 + noise * 0.65
                    : tonal * 0.9 + noise * 0.1
                channel[frame] = Float(mix * envelope * gain)
            }
        }
        drumBuffers[key] = result
        return result
    }

    private func speakBeat(_ beat: Int) {
        guard !speech.isSpeaking else { return }
        let utterance = AVSpeechUtterance(string: MetronomeMath.koreanCountLabel(beatIndex: beat))
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = Float(min(0.58, max(0.42, MetronomeMath.koreanSpeechRate(bpm: settings.bpm) * 0.28)))
        utterance.volume = Float(settings.volume)
        speech.speak(utterance)
    }

    private func resumeAfterInterruption() {
        guard state == .running || state == .interrupted else { return }
        do {
            if !engine.isRunning { try engine.start() }
            if !player.isPlaying { player.play() }
            resynchronize()
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func resynchronize() {
        nextHostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.06)
    }

}

private struct ClickKey: Hashable {
    let sound: ClickSound
    let accent: Bool
    let subdivision: Bool
}

private struct DrumKey: Hashable {
    let instrument: DrumInstrument
    let level: DrumStepLevel
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
