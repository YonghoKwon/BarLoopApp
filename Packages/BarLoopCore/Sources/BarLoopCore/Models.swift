import Foundation

public enum MediaSource: Codable, Equatable, Sendable {
    case localAsset(id: UUID, fileName: String, kind: MediaKind)
    case youtube(videoID: String)

    public var stableKey: String {
        switch self {
        case let .localAsset(id, _, _): "local:\(id.uuidString)"
        case let .youtube(videoID): "youtube:\(videoID)"
        }
    }
}

public enum MediaKind: String, Codable, CaseIterable, Sendable {
    case audio
    case video
}

public enum LoopDefinition: Codable, Equatable, Sendable {
    case bars(start: Int, end: Int)
    case time(start: TimeInterval, end: TimeInterval)
}

public struct BarSegment: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let start: TimeInterval
    public let end: TimeInterval

    public init(index: Int, start: TimeInterval, end: TimeInterval) {
        id = index
        self.start = start
        self.end = end
    }
}

public enum Subdivision: Int, Codable, CaseIterable, Identifiable, Sendable {
    case quarter = 1
    case eighth = 2
    case triplet = 3
    case sixteenth = 4

    public var id: Int { rawValue }
}

public enum ClickSound: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case classic, wood, rim, cowbell, digital, clave, shaker, low
    public var id: String { rawValue }
}

public enum CountMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case click, voice, both
    public var id: String { rawValue }
}

public struct PracticeSettings: Codable, Equatable, Sendable {
    public var bpm: Int
    public var beatsPerBar: Int
    public var firstDownbeat: TimeInterval
    public var playbackRate: Double
    public var preservePitch: Bool
    public var mediaVolume: Double
    public var preRollBeats: Int
    public var loopEnabled: Bool
    public var metronomeEnabled: Bool
    public var countInBars: Int
    public var subdivision: Subdivision
    public var metronomeVolume: Double
    public var syncOffsetMilliseconds: Int

    public init(
        bpm: Int = 120,
        beatsPerBar: Int = 4,
        firstDownbeat: TimeInterval = 0,
        playbackRate: Double = 1,
        preservePitch: Bool = true,
        mediaVolume: Double = 0.85,
        preRollBeats: Int = 4,
        loopEnabled: Bool = true,
        metronomeEnabled: Bool = false,
        countInBars: Int = 1,
        subdivision: Subdivision = .quarter,
        metronomeVolume: Double = 0.55,
        syncOffsetMilliseconds: Int = 0
    ) {
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.firstDownbeat = firstDownbeat
        self.playbackRate = playbackRate
        self.preservePitch = preservePitch
        self.mediaVolume = mediaVolume
        self.preRollBeats = preRollBeats
        self.loopEnabled = loopEnabled
        self.metronomeEnabled = metronomeEnabled
        self.countInBars = countInBars
        self.subdivision = subdivision
        self.metronomeVolume = metronomeVolume
        self.syncOffsetMilliseconds = syncOffsetMilliseconds
    }
}

public struct MetronomeSettings: Codable, Equatable, Sendable {
    public var bpm: Int
    public var beatsPerBar: Int
    public var subdivision: Subdivision
    public var volume: Double
    public var accentVolume: Double
    public var subdivisionVolume: Double
    public var swing: Double
    public var sound: ClickSound
    public var accentSound: ClickSound
    public var accents: [Bool]
    public var gapEnabled: Bool
    public var gapPlayBars: Int
    public var gapMuteBars: Int
    public var autoTempoBars: Int
    public var autoTempoStep: Int

    public init(
        bpm: Int = 120,
        beatsPerBar: Int = 4,
        subdivision: Subdivision = .quarter,
        volume: Double = 0.55,
        accentVolume: Double = 0.82,
        subdivisionVolume: Double = 0.3,
        swing: Double = 0.5,
        sound: ClickSound = .classic,
        accentSound: ClickSound = .wood,
        accents: [Bool] = [true, false, false, false],
        gapEnabled: Bool = false,
        gapPlayBars: Int = 4,
        gapMuteBars: Int = 2,
        autoTempoBars: Int = 0,
        autoTempoStep: Int = 5
    ) {
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.subdivision = subdivision
        self.volume = volume
        self.accentVolume = accentVolume
        self.subdivisionVolume = subdivisionVolume
        self.swing = swing
        self.sound = sound
        self.accentSound = accentSound
        self.accents = accents
        self.gapEnabled = gapEnabled
        self.gapPlayBars = gapPlayBars
        self.gapMuteBars = gapMuteBars
        self.autoTempoBars = autoTempoBars
        self.autoTempoStep = autoTempoStep
    }
}

public struct TempoTrainerSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var startBPM: Int
    public var targetBPM: Int
    public var stepBPM: Int
    public var repeatsPerStep: Int
    public var restSeconds: Int

    public init(
        enabled: Bool = false,
        startBPM: Int = 80,
        targetBPM: Int = 120,
        stepBPM: Int = 5,
        repeatsPerStep: Int = 4,
        restSeconds: Int = 0
    ) {
        self.enabled = enabled
        self.startBPM = startBPM
        self.targetBPM = targetBPM
        self.stepBPM = stepBPM
        self.repeatsPerStep = repeatsPerStep
        self.restSeconds = restSeconds
    }
}

public struct PracticeSection: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var mediaKey: String
    public var name: String
    public var loop: LoopDefinition
    public var note: String
    public var targetRepeats: Int

    public init(
        id: UUID = UUID(),
        mediaKey: String,
        name: String,
        loop: LoopDefinition,
        note: String = "",
        targetRepeats: Int = 4
    ) {
        self.id = id
        self.mediaKey = mediaKey
        self.name = name
        self.loop = loop
        self.note = note
        self.targetRepeats = targetRepeats
    }
}

public struct PracticeSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var activeSeconds: Int
    public var label: String
    public var startBPM: Int?
    public var bestBPM: Int?
    public var completed: Bool
    public var note: String

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        activeSeconds: Int,
        label: String,
        startBPM: Int? = nil,
        bestBPM: Int? = nil,
        completed: Bool,
        note: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = activeSeconds
        self.label = label
        self.startBPM = startBPM
        self.bestBPM = bestBPM
        self.completed = completed
        self.note = note
    }
}

public struct PracticeRoutine: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var steps: [PracticeRoutineStep]

    public init(id: UUID = UUID(), name: String, steps: [PracticeRoutineStep]) {
        self.id = id
        self.name = name
        self.steps = steps
    }
}

public struct PracticeRoutineStep: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var bpm: Int
    public var bars: Int
    public var patternID: String
    public var accentTrainer: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bpm: Int,
        bars: Int,
        patternID: String,
        accentTrainer: Bool
    ) {
        self.id = id
        self.name = name
        self.bpm = bpm
        self.bars = bars
        self.patternID = patternID
        self.accentTrainer = accentTrainer
    }
}

public struct DailyPracticePoint: Equatable, Identifiable, Sendable {
    public let id: String
    public let date: Date
    public var activeSeconds: Int
    public var sessions: Int
    public var completed: Int
    public var bestBPM: Int
}
