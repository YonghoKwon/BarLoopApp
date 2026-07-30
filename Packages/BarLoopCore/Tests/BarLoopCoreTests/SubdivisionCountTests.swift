import Testing
@testable import BarLoopCore

@Suite("Subdivision count labels")
struct SubdivisionCountTests {
    @Test func buildsSixteenthNoteCounting() {
        #expect(MetronomeMath.countGroup(beatIndex: 0, subdivision: .sixteenth) == ["1", "e", "&", "a"])
        #expect(MetronomeMath.countGroup(beatIndex: 1, subdivision: .sixteenth) == ["2", "e", "&", "a"])
    }

    @Test func supportsEighthNotesAndTriplets() {
        #expect(MetronomeMath.countGroup(beatIndex: 0, subdivision: .eighth) == ["1", "&"])
        #expect(MetronomeMath.countGroup(beatIndex: 0, subdivision: .triplet) == ["1", "trip", "let"])
    }

    @Test func buildsFullMeasureAndCurrentPosition() {
        #expect(MetronomeMath.countGroups(beatsPerBar: 2, subdivision: .sixteenth) == [
            ["1", "e", "&", "a"],
            ["2", "e", "&", "a"],
        ])
        #expect(MetronomeMath.currentCountLabel(
            beatIndex: 2, subdivisionIndex: 1, subdivision: .sixteenth
        ) == "3 e")
        #expect(MetronomeMath.currentCountLabel(
            beatIndex: 2, subdivisionIndex: 2, subdivision: .sixteenth
        ) == "3 &")
        #expect(MetronomeMath.currentCountLabel(
            beatIndex: 2, subdivisionIndex: 3, subdivision: .sixteenth
        ) == "3 a")
    }

    @Test func keepsSixteenthVisualGridForQuarterAndEighthClicks() {
        #expect(MetronomeMath.visualSubdivision(for: .quarter) == .sixteenth)
        #expect(MetronomeMath.visualSubdivision(for: .eighth) == .sixteenth)
        #expect(MetronomeMath.visualSubdivision(for: .triplet) == .triplet)
        #expect(MetronomeMath.visualSubdivision(for: .sixteenth) == .sixteenth)
    }

    @Test func marksCellsThatProduceSound() {
        #expect([0, 1, 2, 3].map {
            MetronomeMath.isSoundCell(playback: .quarter, visualIndex: $0)
        } == [true, false, false, false])
        #expect([0, 1, 2, 3].map {
            MetronomeMath.isSoundCell(playback: .eighth, visualIndex: $0)
        } == [true, false, true, false])
        #expect([0, 1, 2, 3].map {
            MetronomeMath.isSoundCell(playback: .sixteenth, visualIndex: $0)
        } == [true, true, true, true])
        #expect(MetronomeMath.visualIndex(playback: .eighth, index: 1) == 2)
    }
}
