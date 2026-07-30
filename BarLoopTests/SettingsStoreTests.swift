import BarLoopCore
import XCTest
@testable import BarLoop

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsStoreTests")
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
        defaults = nil
        super.tearDown()
    }

    func testSettingsPersistAcrossInstances() {
        let first = SettingsStore(defaults: defaults)
        first.practice.bpm = 138
        first.metronome.gapEnabled = true
        first.tempoTrainer.enabled = true
        first.keepAwake = false

        let second = SettingsStore(defaults: defaults)
        XCTAssertEqual(second.practice.bpm, 138)
        XCTAssertTrue(second.metronome.gapEnabled)
        XCTAssertTrue(second.tempoTrainer.enabled)
        XCTAssertFalse(second.keepAwake)
    }

    func testBackupSettingsApplyAtomically() {
        let store = SettingsStore(defaults: defaults)
        var practice = PracticeSettings()
        practice.bpm = 90
        var metronome = MetronomeSettings()
        metronome.subdivision = .triplet
        let backup = BarLoopBackup(
            practiceSettings: practice,
            metronomeSettings: metronome,
            sections: [],
            sessions: [],
            patterns: [],
            routines: []
        )

        store.apply(backup)

        XCTAssertEqual(store.practice.bpm, 90)
        XCTAssertEqual(store.metronome.subdivision, .triplet)
    }
}
