import Foundation
import Testing
@testable import BarLoopCore

@Suite("Drum patterns and history")
struct DrumAndHistoryTests {
    @Test func drumCellsAndMeters() {
        #expect(DrumStepLevel.off.next == .normal)
        #expect(DrumStepLevel.normal.next == .accent)
        #expect(DrumStepLevel.accent.next == .off)
        #expect(DrumLibrary.presets.first { $0.id == "five-four-rock" }?.stepCount == 20)
        #expect(DrumLibrary.presets.first { $0.id == "seven-four-drive" }?.stepCount == 28)
        #expect(DrumLibrary.defaultRoutine.steps.reduce(0) { $0 + $1.bars } == 24)
        #expect(DrumLibrary.nextAccent(current: 15, mode: .forward, totalSteps: 16) == 0)
        #expect(DrumLibrary.nextAccent(current: 0, mode: .random, totalSteps: 28, random: { 0 }) == 1)
    }

    @Test func dailyHistoryAndStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        func session(_ day: String, seconds: Int, bpm: Int = 0) -> PracticeSession {
            let start = formatter.date(from: "\(day)T12:00:00Z")!
            return .init(
                startedAt: start,
                endedAt: start.addingTimeInterval(600),
                activeSeconds: seconds,
                label: "Practice",
                bestBPM: bpm,
                completed: true
            )
        }
        let now = formatter.date(from: "2026-07-26T12:00:00Z")!
        let sessions = [
            session("2026-07-25", seconds: 600, bpm: 120),
            session("2026-07-25", seconds: 300, bpm: 130),
            session("2026-07-26", seconds: 300),
        ]
        let points = PracticeMath.dailySeries(sessions: sessions, days: 3, now: now, calendar: calendar)
        #expect(points.map(\.activeSeconds) == [0, 900, 300])
        #expect(points[1].sessions == 2)
        #expect(points[1].bestBPM == 130)
        #expect(PracticeMath.practiceStreak(sessions: sessions, now: now, calendar: calendar) == 2)
    }

    @Test func backupRoundTrip() throws {
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

