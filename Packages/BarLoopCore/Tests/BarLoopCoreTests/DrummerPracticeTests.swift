import Testing
@testable import BarLoopCore

@Suite("Drummer practice helpers")
struct DrummerPracticeTests {
    @Test func cyclesSequencerCells() {
        #expect(DrumStepLevel.off.next == .normal)
        #expect(DrumStepLevel.normal.next == .accent)
        #expect(DrumStepLevel.accent.next == .off)
    }

    @Test func clonesPatternsWithoutSharingStepArrays() {
        let source = DrumLibrary.presets[0]
        var copy = source
        var kick = copy.steps[.kick] ?? []
        kick[0] = .off
        copy.steps[.kick] = kick

        #expect(source.steps[.kick]?[0] == .accent)
        #expect(copy.steps[.kick]?[0] == .off)
    }

    @Test func normalizesInvalidStoredPatternData() {
        let pattern = DrumPattern(
            id: "stored",
            name: "Stored",
            detail: "",
            rawSteps: [.kick: [9, 2, 1], .snare: [], .hihat: [1]]
        )

        #expect(pattern.steps[.kick]?.count == 16)
        #expect(pattern.steps[.kick]?.prefix(3) == [.off, .accent, .normal])
        #expect(pattern.steps[.hihat]?[0] == .normal)
    }

    @Test func resizesPatternsWhilePreservingCells() {
        var pattern = DrumLibrary.custom
        let firstKick = pattern.steps[.kick]?[0]
        pattern.resize(beats: 7)

        #expect(pattern.beatsPerBar == 7)
        #expect(DrumLibrary.stepCount(beatsPerBar: 7) == 28)
        #expect(pattern.steps[.kick]?.count == 28)
        #expect(pattern.steps[.kick]?[0] == firstKick)
    }

    @Test func includesSyncopationAndOddMeterPresets() {
        #expect(DrumLibrary.pattern(id: "offbeat-eighths").beatsPerBar == 4)
        #expect(DrumLibrary.pattern(id: "five-four-rock").steps[.kick]?.count == 20)
        #expect(DrumLibrary.pattern(id: "seven-four-drive").steps[.ride]?.count == 28)
    }

    @Test func resolvesPresetAndCustomPatterns() {
        let custom = DrumLibrary.custom
        #expect(DrumLibrary.pattern(id: "half-time").id == "half-time")
        #expect(DrumLibrary.pattern(id: "custom", custom: custom).id == "custom")
    }

    @Test func movesAccentsWithoutRepeatingRandomCell() {
        #expect(DrumLibrary.nextAccent(current: 15, mode: .forward, totalSteps: 16) == 0)
        #expect(DrumLibrary.nextAccent(current: 27, mode: .forward, totalSteps: 28) == 0)
        #expect(DrumLibrary.nextAccent(current: 0, mode: .random, totalSteps: 28, random: { 0 }) == 1)
    }

    @Test func calculatesCompleteRoutineBarCount() {
        #expect(DrumLibrary.defaultRoutine.steps.reduce(0) { $0 + $1.bars } == 24)
    }
}
