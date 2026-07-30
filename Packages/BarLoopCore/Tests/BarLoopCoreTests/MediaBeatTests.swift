import Testing
@testable import BarLoopCore

@Suite("Media beat position")
struct MediaBeatTests {
    @Test func tracksSixteenthNotePositions() {
        #expect(position(at: 0).beatInBar == 0)
        #expect(position(at: 0).subdivisionInBeat == 0)
        #expect(position(at: 0.125).subdivisionInBeat == 1)
        #expect(position(at: 0.25).subdivisionInBeat == 2)
        #expect(position(at: 0.5).beatInBar == 1)
    }

    @Test func appliesPositiveAndNegativeSyncOffsets() {
        let positive = PracticeMath.beatPosition(
            mediaTime: 0.5, bpm: 120, beatsPerBar: 4,
            subdivision: .quarter, firstDownbeat: 0, syncOffsetMilliseconds: 100
        )
        let negative = PracticeMath.beatPosition(
            mediaTime: 0.5, bpm: 120, beatsPerBar: 4,
            subdivision: .quarter, firstDownbeat: 0, syncOffsetMilliseconds: -100
        )
        #expect(positive.beatInBar == 0)
        #expect(negative.beatInBar == 1)
    }

    @Test func reportsPositionsBeforeFirstDownbeat() {
        let value = PracticeMath.beatPosition(
            mediaTime: 1, bpm: 120, beatsPerBar: 4,
            subdivision: .sixteenth, firstDownbeat: 2
        )
        #expect(value.beforeDownbeat)
        #expect(value.absoluteSubdivisionIndex == -1)
    }

    private func position(at time: Double) -> MediaBeatPosition {
        PracticeMath.beatPosition(
            mediaTime: time, bpm: 120, beatsPerBar: 4,
            subdivision: .sixteenth, firstDownbeat: 0
        )
    }
}
