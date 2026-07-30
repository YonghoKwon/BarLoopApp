import Foundation
import Testing
@testable import BarLoopCore

@Suite("Practice history summaries")
struct PracticeHistoryTests {
    @Test func groupsSessionsIntoDailyChartPoints() {
        let context = context()
        let sessions = [
            context.session("2026-07-25", seconds: 600, bpm: 120),
            context.session("2026-07-25", seconds: 300, bpm: 130),
        ]
        let points = PracticeMath.dailySeries(
            sessions: sessions, days: 3, now: context.now, calendar: context.calendar
        )

        #expect(points.map(\.activeSeconds) == [0, 900, 0])
        #expect(points[1].sessions == 2)
        #expect(points[1].completed == 2)
        #expect(points[1].bestBPM == 130)
    }

    @Test func countsConsecutiveActiveDaysEndingToday() {
        let context = context()
        let sessions = [
            context.session("2026-07-26", seconds: 300),
            context.session("2026-07-25", seconds: 300),
            context.session("2026-07-23", seconds: 300),
        ]
        #expect(PracticeMath.practiceStreak(
            sessions: sessions, now: context.now, calendar: context.calendar
        ) == 2)
    }

    private func context() -> HistoryContext {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        return HistoryContext(
            calendar: calendar,
            now: formatter.date(from: "2026-07-26T12:00:00Z")!,
            formatter: formatter
        )
    }
}

private struct HistoryContext {
    let calendar: Calendar
    let now: Date
    let formatter: ISO8601DateFormatter

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
}
