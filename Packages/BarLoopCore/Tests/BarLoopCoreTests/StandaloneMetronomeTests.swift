import Testing
@testable import BarLoopCore

@Suite("Standalone metronome recovery and gap click")
struct StandaloneMetronomeTests {
    @Test func resynchronizesWhenSchedulerIsFarBehind() {
        #expect(MetronomeMath.shouldResynchronize(nextNoteTime: 4.7, currentTime: 5))
    }

    @Test func resynchronizesWhenScheduleIsFarAhead() {
        #expect(MetronomeMath.shouldResynchronize(nextNoteTime: 7.1, currentTime: 5))
    }

    @Test func keepsHealthyNearFutureSchedule() {
        #expect(!MetronomeMath.shouldResynchronize(nextNoteTime: 5.08, currentTime: 5))
    }

    @Test func keepsAllBarsAudibleWhenGapIsDisabled() {
        #expect(MetronomeMath.isBarAudible(
            barIndex: 9, gapEnabled: false, playBars: 4, muteBars: 2
        ))
    }

    @Test func playsFourBarsAndMutesTwo() {
        let sequence = (0...6).map {
            MetronomeMath.isBarAudible(
                barIndex: $0, gapEnabled: true, playBars: 4, muteBars: 2
            )
        }
        #expect(sequence == [true, true, true, true, false, false, true])
    }
}
