import Testing
@testable import BarLoopCore

@Suite("Korean beat count voice")
struct KoreanCountVoiceTests {
    @Test func mapsBeatIndexesToKoreanWords() {
        #expect([0, 1, 2, 3, 7, 11].map(MetronomeMath.koreanCountLabel) == [
            "하나", "둘", "셋", "넷", "여덟", "열둘",
        ])
    }

    @Test func increasesSpeakingRateWithinSafeBounds() {
        #expect(MetronomeMath.koreanSpeechRate(bpm: 40) == 0.8)
        #expect(MetronomeMath.koreanSpeechRate(bpm: 95) == 1)
        #expect(MetronomeMath.koreanSpeechRate(bpm: 300) == 2)
    }
}
