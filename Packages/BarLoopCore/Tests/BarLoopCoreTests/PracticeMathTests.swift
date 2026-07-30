import Foundation
import Testing
@testable import BarLoopCore

@Suite("Practice math regression")
struct PracticeMathTests {
    @Test func bpmInput() {
        #expect(PracticeMath.normalizeBPMText("088") == "88")
        #expect(PracticeMath.normalizeBPMText("000120") == "120")
        #expect(PracticeMath.normalizeBPMText("abc") == "")
        #expect(PracticeMath.normalizeBPMText("1a2b0") == "120")
        #expect(PracticeMath.normalizeBPMText("999") == "400")
        #expect(PracticeMath.clampBPM(5) == 20)
        #expect(PracticeMath.clampBPM(88.4) == 88)
        #expect(PracticeMath.parseBPMText("", fallback: 96) == 96)
    }

    @Test func timeAndBars() {
        #expect(PracticeMath.formatTime(65.25) == "1:05")
        #expect(PracticeMath.formatTime(65.25, precise: true) == "1:05.25")
        #expect(PracticeMath.parseTime("1:05.25") == 65.25)
        let bars = PracticeMath.generateBars(duration: 9, bpm: 120, beatsPerBar: 4, firstDownbeat: 1)
        #expect(bars.count == 4)
        #expect(bars[0].start == 1)
        #expect(bars[3].end == 9)
    }

    @Test func youtubeIDs() {
        #expect(PracticeMath.extractYouTubeID("M7lc1UVf-VE") == "M7lc1UVf-VE")
        #expect(PracticeMath.extractYouTubeID("https://youtu.be/M7lc1UVf-VE") == "M7lc1UVf-VE")
        #expect(PracticeMath.extractYouTubeID("https://youtube.com/shorts/M7lc1UVf-VE") == "M7lc1UVf-VE")
        #expect(PracticeMath.extractYouTubeID("https://example.com/video") == nil)
    }

    @Test func mediaBeatPosition() {
        #expect(PracticeMath.beatPosition(
            mediaTime: 0.125, bpm: 120, beatsPerBar: 4,
            subdivision: .sixteenth, firstDownbeat: 0
        ).subdivisionInBeat == 1)
        #expect(PracticeMath.beatPosition(
            mediaTime: 0.5, bpm: 120, beatsPerBar: 4,
            subdivision: .quarter, firstDownbeat: 0, syncOffsetMilliseconds: 100
        ).beatInBar == 0)
        #expect(PracticeMath.beatPosition(
            mediaTime: 1, bpm: 120, beatsPerBar: 4,
            subdivision: .sixteenth, firstDownbeat: 2
        ).beforeDownbeat)
    }
}

