import Foundation

public enum DrumInstrument: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case crash, ride, hihat, rackTom, midTom, floorTom, snare, kick
    public var id: String { rawValue }
}

public enum DrumStepLevel: Int, Codable, CaseIterable, Hashable, Sendable {
    case off = 0
    case normal = 1
    case accent = 2

    public var next: DrumStepLevel {
        switch self {
        case .off: .normal
        case .normal: .accent
        case .accent: .off
        }
    }
}

public struct DrumPattern: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var detail: String
    public var beatsPerBar: Int
    public var swing: Double
    public var steps: [DrumInstrument: [DrumStepLevel]]

    public init(
        id: String,
        name: String,
        detail: String,
        beatsPerBar: Int = 4,
        swing: Double = 0.5,
        steps: [DrumInstrument: [DrumStepLevel]]
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.beatsPerBar = max(2, min(12, beatsPerBar))
        self.swing = min(0.75, max(0.5, swing))
        self.steps = steps
        normalizeSteps()
    }

    public var stepCount: Int { beatsPerBar * 4 }

    public mutating func resize(beats: Int) {
        beatsPerBar = max(2, min(12, beats))
        normalizeSteps()
    }

    public mutating func cycle(instrument: DrumInstrument, step: Int) {
        guard step >= 0, step < stepCount else { return }
        normalizeSteps()
        var values = steps[instrument] ?? []
        values[step] = values[step].next
        steps[instrument] = values
    }

    private mutating func normalizeSteps() {
        for instrument in DrumInstrument.allCases {
            var values = steps[instrument] ?? []
            if values.count < stepCount {
                values.append(contentsOf: repeatElement(.off, count: stepCount - values.count))
            } else if values.count > stepCount {
                values = Array(values.prefix(stepCount))
            }
            steps[instrument] = values
        }
    }
}

public enum DrumLibrary {
    public static let presets: [DrumPattern] = [
        make(
            id: "basic-rock",
            name: "8 Beat Rock",
            detail: "Eighth-note hi-hat with backbeat and a basic kick pattern.",
            hits: [
                .crash: [0: .accent],
                .hihat: [0: .accent, 2: .normal, 4: .normal, 6: .normal, 8: .accent, 10: .normal, 12: .normal, 14: .normal],
                .snare: [4: .accent, 12: .accent],
                .kick: [0: .accent, 6: .normal, 8: .accent, 14: .normal],
            ]
        ),
        make(
            id: "syncopated-sixteenth",
            name: "16th Syncopation",
            detail: "Ghosted snare and kick placements across e, &, and a.",
            hits: [
                .hihat: Dictionary(uniqueKeysWithValues: (0..<16).map { ($0, $0.isMultiple(of: 4) ? .accent : .normal) }),
                .snare: [3: .normal, 4: .accent, 6: .normal, 9: .normal, 12: .accent, 15: .normal],
                .kick: [0: .accent, 2: .normal, 5: .normal, 8: .accent, 11: .normal, 13: .normal],
            ]
        ),
        make(
            id: "shuffle",
            name: "Shuffle",
            detail: "Long-short swing flow with a strong backbeat.",
            swing: 0.66,
            hits: [
                .hihat: [0: .accent, 2: .normal, 4: .normal, 6: .normal, 8: .accent, 10: .normal, 12: .normal, 14: .normal],
                .snare: [4: .accent, 12: .accent],
                .kick: [0: .accent, 6: .normal, 8: .accent, 14: .normal],
            ]
        ),
        make(
            id: "five-four-rock",
            name: "5/4 Rock · 3+2",
            detail: "A five-beat groove grouped as 3+2.",
            beats: 5,
            hits: [
                .crash: [0: .accent],
                .hihat: Dictionary(uniqueKeysWithValues: stride(from: 0, to: 20, by: 2).map { ($0, $0.isMultiple(of: 8) ? .accent : .normal) }),
                .snare: [4: .accent, 12: .accent, 18: .accent],
                .kick: [0: .accent, 6: .normal, 8: .accent, 12: .accent, 18: .normal],
            ]
        ),
        make(
            id: "seven-four-drive",
            name: "7/4 Drive · 4+3",
            detail: "A driving seven-beat groove grouped as 4+3.",
            beats: 7,
            hits: [
                .crash: [0: .accent],
                .ride: Dictionary(uniqueKeysWithValues: stride(from: 0, to: 28, by: 2).map { ($0, $0.isMultiple(of: 8) ? .accent : .normal) }),
                .snare: [4: .accent, 12: .accent, 18: .accent, 24: .accent],
                .kick: [0: .accent, 6: .normal, 8: .accent, 13: .normal, 16: .accent, 22: .normal, 24: .accent, 27: .normal],
            ]
        ),
    ]

    public static var custom: DrumPattern {
        var pattern = presets[0]
        pattern.id = "custom"
        pattern.name = "My Pattern"
        pattern.detail = "Editable 4/5-piece kit pattern."
        return pattern
    }

    public static let defaultRoutine = PracticeRoutine(
        name: "Default Routine",
        steps: [
            .init(name: "Warm-up", bpm: 80, bars: 8, patternID: "basic-rock", accentTrainer: false),
            .init(name: "16th Control", bpm: 75, bars: 8, patternID: "syncopated-sixteenth", accentTrainer: true),
            .init(name: "Odd Meter", bpm: 90, bars: 8, patternID: "five-four-rock", accentTrainer: false),
        ]
    )

    public static func nextAccent(
        current: Int,
        mode: AccentMovement,
        totalSteps: Int,
        random: () -> Double = { Double.random(in: 0..<1) }
    ) -> Int {
        let total = max(1, totalSteps)
        if mode == .forward { return (current + 1) % total }
        guard total > 1 else { return 0 }
        let raw = min(total - 2, max(0, Int(floor(random() * Double(total - 1)))))
        return raw >= current ? raw + 1 : raw
    }

    private static func make(
        id: String,
        name: String,
        detail: String,
        beats: Int = 4,
        swing: Double = 0.5,
        hits: [DrumInstrument: [Int: DrumStepLevel]]
    ) -> DrumPattern {
        let count = beats * 4
        let steps = Dictionary(uniqueKeysWithValues: DrumInstrument.allCases.map { instrument in
            let values = (0..<count).map { hits[instrument]?[$0] ?? .off }
            return (instrument, values)
        })
        return .init(id: id, name: name, detail: detail, beatsPerBar: beats, swing: swing, steps: steps)
    }
}

public enum AccentMovement: String, Codable, CaseIterable, Sendable {
    case forward
    case random
}
