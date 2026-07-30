import Foundation

public enum MetronomeMath {
    public static func shouldResynchronize(nextNoteTime: TimeInterval, currentTime: TimeInterval) -> Bool {
        nextNoteTime < currentTime - 0.18 || nextNoteTime > currentTime + 1
    }

    public static func isBarAudible(
        barIndex: Int,
        gapEnabled: Bool,
        playBars: Int,
        muteBars: Int
    ) -> Bool {
        guard gapEnabled, muteBars > 0 else { return true }
        let cycle = max(1, playBars + muteBars)
        return barIndex % cycle < playBars
    }

    public static func interval(
        bpm: Int,
        subdivision: Subdivision,
        swing: Double,
        stepIndex: Int
    ) -> TimeInterval {
        let base = 60 / Double(PracticeMath.clampBPM(Double(bpm))) / Double(subdivision.rawValue)
        guard [.eighth, .sixteenth].contains(subdivision), swing > 0.5 else { return base }
        let safeSwing = min(0.75, max(0.5, swing))
        return stepIndex.isMultiple(of: 2)
            ? base * 2 * safeSwing
            : base * 2 * (1 - safeSwing)
    }

    public static func countTokens(for subdivision: Subdivision) -> [String] {
        switch subdivision {
        case .quarter: [""]
        case .eighth: ["", "&"]
        case .triplet: ["", "trip", "let"]
        case .sixteenth: ["", "e", "&", "a"]
        }
    }

    public static func countGroup(beatIndex: Int, subdivision: Subdivision) -> [String] {
        countTokens(for: subdivision).enumerated().map { index, token in
            index == 0 ? String(beatIndex + 1) : token
        }
    }

    public static func visualSubdivision(for playback: Subdivision) -> Subdivision {
        playback == .triplet ? .triplet : .sixteenth
    }

    public static func visualIndex(playback: Subdivision, index: Int) -> Int {
        playback == .eighth ? index * 2 : index
    }

    public static func isSoundCell(playback: Subdivision, visualIndex: Int) -> Bool {
        switch playback {
        case .quarter: visualIndex == 0
        case .eighth: visualIndex == 0 || visualIndex == 2
        case .triplet: visualIndex < 3
        case .sixteenth: visualIndex < 4
        }
    }

    public static func koreanCountLabel(beatIndex: Int) -> String {
        let words = ["하나", "둘", "셋", "넷", "다섯", "여섯", "일곱", "여덟", "아홉", "열", "열하나", "열둘"]
        return words[max(0, min(words.count - 1, beatIndex))]
    }

    public static func koreanSpeechRate(bpm: Int) -> Double {
        min(2, max(0.8, Double(bpm) / 95))
    }
}

