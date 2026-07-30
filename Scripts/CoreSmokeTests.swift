import Foundation

@main
enum CoreSmokeTests {
    static func main() throws {
        check(PracticeMath.normalizeBPMText("088") == "88", "leading-zero BPM")
        check(PracticeMath.clampBPM(900) == 400, "maximum BPM")
        check(PracticeMath.parseTime("1:05.25") == 65.25, "time parsing")

        let bars = PracticeMath.generateBars(
            duration: 9,
            bpm: 120,
            beatsPerBar: 4,
            firstDownbeat: 1
        )
        check(bars.count == 4 && bars.last?.end == 9, "bar generation")
        check(
            PracticeMath.extractYouTubeID("https://youtu.be/M7lc1UVf-VE") == "M7lc1UVf-VE",
            "YouTube parsing"
        )

        let beat = PracticeMath.beatPosition(
            mediaTime: 0.125,
            bpm: 120,
            beatsPerBar: 4,
            subdivision: .sixteenth,
            firstDownbeat: 0
        )
        check(beat.beatInBar == 0 && beat.subdivisionInBeat == 1, "media beat position")
        check(
            MetronomeMath.shouldResynchronize(nextNoteTime: 4.7, currentTime: 5),
            "scheduler recovery"
        )
        check(
            (0...6).map {
                MetronomeMath.isBarAudible(
                    barIndex: $0,
                    gapEnabled: true,
                    playBars: 4,
                    muteBars: 2
                )
            } == [true, true, true, true, false, false, true],
            "gap click"
        )
        check(
            MetronomeMath.countGroup(beatIndex: 0, subdivision: .sixteenth) == ["1", "e", "&", "a"],
            "subdivision labels"
        )
        check(MetronomeMath.koreanCountLabel(beatIndex: 11) == "열둘", "Korean count")
        check(
            DrumLibrary.presets.first(where: { $0.id == "seven-four-drive" })?.stepCount == 28,
            "odd-meter pattern"
        )
        check(
            DrumLibrary.defaultRoutine.steps.reduce(0) { $0 + $1.bars } == 24,
            "routine bars"
        )

        let backup = BarLoopBackup(
            practiceSettings: .init(),
            metronomeSettings: .init(),
            tempoTrainerSettings: .init(enabled: true),
            sections: [],
            sessions: [],
            patterns: DrumLibrary.presets,
            routines: [DrumLibrary.defaultRoutine]
        )
        let decoded = try BackupCodec.decode(BackupCodec.encode(backup))
        check(decoded.version == 1 && decoded.tempoTrainerSettings.enabled, "backup round trip")
        print("BarLoopCore smoke tests passed")
    }

    private static func check(
        _ condition: @autoclosure () -> Bool,
        _ name: String
    ) {
        guard condition() else {
            fputs("FAILED: \(name)\n", stderr)
            exit(1)
        }
    }
}

