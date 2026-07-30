import Foundation

public enum PracticeMath {
    public static func clampBPM(_ value: Double, min: Int = 20, max: Int = 400) -> Int {
        guard value.isFinite else { return min }
        return Swift.min(max, Swift.max(min, Int(value.rounded())))
    }

    public static func normalizeBPMText(_ value: String, max: Int = 400) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty, let number = Int(digits) else { return "" }
        return String(Swift.min(max, number))
    }

    public static func parseBPMText(
        _ value: String,
        fallback: Int,
        min: Int = 20,
        max: Int = 400
    ) -> Int {
        let normalized = normalizeBPMText(value, max: max)
        guard let value = Int(normalized) else {
            return clampBPM(Double(fallback), min: min, max: max)
        }
        return clampBPM(Double(value), min: min, max: max)
    }

    public static func formatTime(_ value: TimeInterval, precise: Bool = false) -> String {
        let safe = value.isFinite ? Swift.max(0, value) : 0
        let minutes = Int(safe / 60)
        let seconds = safe - Double(minutes * 60)
        if precise {
            return String(format: "%d:%05.2f", minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, Int(seconds))
    }

    public static func parseTime(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":")
        if parts.count == 1, let seconds = Double(parts[0]), seconds >= 0 {
            return seconds
        }
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]),
              minutes >= 0,
              seconds >= 0 else { return nil }
        return minutes * 60 + seconds
    }

    public static func generateBars(
        duration: TimeInterval,
        bpm: Double,
        beatsPerBar: Int,
        firstDownbeat: TimeInterval
    ) -> [BarSegment] {
        guard duration.isFinite, duration > 0,
              bpm.isFinite, bpm > 0,
              beatsPerBar > 0 else { return [] }
        let length = 60 / bpm * Double(beatsPerBar)
        let start = min(duration, max(0, firstDownbeat))
        var bars: [BarSegment] = []
        var cursor = start
        var index = 0
        while cursor < duration {
            bars.append(.init(index: index, start: cursor, end: min(cursor + length, duration)))
            cursor += length
            index += 1
        }
        return bars
    }

    public static func extractYouTubeID(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        if trimmed.count == 11, trimmed.unicodeScalars.allSatisfy(allowed.contains) {
            return trimmed
        }
        guard let components = URLComponents(string: trimmed),
              let rawHost = components.host?.lowercased() else { return nil }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        if host == "youtu.be" {
            return components.path.split(separator: "/").first.map(String.init)
        }
        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        if components.path == "/watch" {
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }
        let path = components.path.split(separator: "/").map(String.init)
        if path.count >= 2, ["embed", "shorts", "live"].contains(path[0]) {
            return path[1]
        }
        return nil
    }

    public static func beatPosition(
        mediaTime: TimeInterval,
        bpm: Double,
        beatsPerBar: Int,
        subdivision: Subdivision,
        firstDownbeat: TimeInterval,
        syncOffsetMilliseconds: Int = 0
    ) -> MediaBeatPosition {
        let safeBPM = Double(clampBPM(bpm))
        let safeBeats = max(1, min(32, beatsPerBar))
        let effectiveTime = max(0, mediaTime) - max(0, firstDownbeat)
            - Double(max(-500, min(500, syncOffsetMilliseconds))) / 1_000
        guard effectiveTime >= 0 else {
            return .init(
                beatInBar: 0,
                subdivisionInBeat: 0,
                barIndex: 0,
                absoluteSubdivisionIndex: -1,
                beforeDownbeat: true
            )
        }
        let subdivisionDuration = 60 / safeBPM / Double(subdivision.rawValue)
        let absoluteSubdivision = max(0, Int(floor((effectiveTime + 0.000_001) / subdivisionDuration)))
        let absoluteBeat = absoluteSubdivision / subdivision.rawValue
        return .init(
            beatInBar: absoluteBeat % safeBeats,
            subdivisionInBeat: absoluteSubdivision % subdivision.rawValue,
            barIndex: absoluteBeat / safeBeats,
            absoluteSubdivisionIndex: absoluteSubdivision,
            beforeDownbeat: false
        )
    }

    public static func dailySeries(
        sessions: [PracticeSession],
        days: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyPracticePoint] {
        let count = max(1, min(31, days))
        let end = calendar.startOfDay(for: now)
        var points = (0..<count).map { offset -> DailyPracticePoint in
            let date = calendar.date(byAdding: .day, value: offset - count + 1, to: end) ?? end
            return .init(
                id: dayKey(date, calendar: calendar),
                date: date,
                activeSeconds: 0,
                sessions: 0,
                completed: 0,
                bestBPM: 0
            )
        }
        let indexes = Dictionary(uniqueKeysWithValues: points.enumerated().map { ($1.id, $0) })
        for session in sessions {
            guard let index = indexes[dayKey(session.startedAt, calendar: calendar)] else { continue }
            points[index].activeSeconds += max(0, session.activeSeconds)
            points[index].sessions += 1
            points[index].completed += session.completed ? 1 : 0
            points[index].bestBPM = max(points[index].bestBPM, session.bestBPM ?? 0)
        }
        return points
    }

    public static func practiceStreak(
        sessions: [PracticeSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let activeDays = Set(sessions.filter { $0.activeSeconds > 0 }.map {
            dayKey($0.startedAt, calendar: calendar)
        })
        var cursor = calendar.startOfDay(for: now)
        var result = 0
        while activeDays.contains(dayKey(cursor, calendar: calendar)) {
            result += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor.addingTimeInterval(-86_400)
        }
        return result
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

public struct MediaBeatPosition: Equatable, Sendable {
    public let beatInBar: Int
    public let subdivisionInBeat: Int
    public let barIndex: Int
    public let absoluteSubdivisionIndex: Int
    public let beforeDownbeat: Bool

    public init(
        beatInBar: Int,
        subdivisionInBeat: Int,
        barIndex: Int,
        absoluteSubdivisionIndex: Int,
        beforeDownbeat: Bool
    ) {
        self.beatInBar = beatInBar
        self.subdivisionInBeat = subdivisionInBeat
        self.barIndex = barIndex
        self.absoluteSubdivisionIndex = absoluteSubdivisionIndex
        self.beforeDownbeat = beforeDownbeat
    }
}

