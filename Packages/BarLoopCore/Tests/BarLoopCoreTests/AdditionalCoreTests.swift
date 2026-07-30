import Foundation
import Testing
@testable import BarLoopCore

@Suite("Native iOS additions")
struct AdditionalCoreTests {
    @Test func formatsTimeAndGeneratesBars() {
        #expect(PracticeMath.formatTime(65.25) == "1:05")
        #expect(PracticeMath.formatTime(65.25, precise: true) == "1:05.25")
        #expect(PracticeMath.parseTime("1:05.25") == 65.25)
        let bars = PracticeMath.generateBars(
            duration: 9, bpm: 120, beatsPerBar: 4, firstDownbeat: 1
        )
        #expect(bars.count == 4)
        #expect(bars[0].start == 1)
        #expect(bars[3].end == 9)
    }

    @Test func extractsSupportedYouTubeIDs() {
        #expect(PracticeMath.extractYouTubeID("M7lc1UVf-VE") == "M7lc1UVf-VE")
        #expect(PracticeMath.extractYouTubeID("https://youtu.be/M7lc1UVf-VE") == "M7lc1UVf-VE")
        #expect(PracticeMath.extractYouTubeID("https://youtube.com/shorts/M7lc1UVf-VE") == "M7lc1UVf-VE")
        #expect(PracticeMath.extractYouTubeID("https://example.com/video") == nil)
    }

    @Test func backupRoundTrips() throws {
        let backup = BarLoopBackup(
            practiceSettings: .init(),
            metronomeSettings: .init(),
            sections: [],
            sessions: [],
            patterns: DrumLibrary.presets,
            routines: [DrumLibrary.defaultRoutine]
        )
        let data = try BackupCodec.encode(backup)
        let decoded = try BackupCodec.decode(data)
        #expect(decoded.version == 1)
        #expect(decoded.patterns.count == DrumLibrary.presets.count)
    }
}
