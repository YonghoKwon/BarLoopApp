import Testing
@testable import BarLoopCore

@Suite("Metronome regression")
struct MetronomeMathTests {
    @Test func schedulerRecovery() {
        #expect(MetronomeMath.shouldResynchronize(nextNoteTime: 4.7, currentTime: 5))
        #expect(MetronomeMath.shouldResynchronize(nextNoteTime: 7.1, currentTime: 5))
        #expect(!MetronomeMath.shouldResynchronize(nextNoteTime: 5.08, currentTime: 5))
    }

    @Test func gapClick() {
        let sequence = (0...6).map {
            MetronomeMath.isBarAudible(barIndex: $0, gapEnabled: true, playBars: 4, muteBars: 2)
        }
        #expect(sequence == [true, true, true, true, false, false, true])
    }

    @Test func subdivisionLabels() {
        #expect(MetronomeMath.countGroup(beatIndex: 0, subdivision: .sixteenth) == ["1", "e", "&", "a"])
        #expect(MetronomeMath.countGroup(beatIndex: 0, subdivision: .triplet) == ["1", "trip", "let"])
        #expect(MetronomeMath.visualSubdivision(for: .quarter) == .sixteenth)
        #expect([0, 1, 2, 3].map {
            MetronomeMath.isSoundCell(playback: .eighth, visualIndex: $0)
        } == [true, false, true, false])
    }

    @Test func koreanVoice() {
        #expect([0, 1, 2, 3, 7, 11].map(MetronomeMath.koreanCountLabel) == [
            "하나", "둘", "셋", "넷", "여덟", "열둘",
        ])
        #expect(MetronomeMath.koreanSpeechRate(bpm: 40) == 0.8)
        #expect(MetronomeMath.koreanSpeechRate(bpm: 95) == 1)
        #expect(MetronomeMath.koreanSpeechRate(bpm: 300) == 2)
    }
}

