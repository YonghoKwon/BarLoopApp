import Foundation
import Testing
@testable import BarLoopCore

@Suite("Playback session audio bridge")
struct AudioPlaybackSessionTests {
    @Test func buildsValidMonoPCMWAVPayload() {
        let bytes = PlaybackSessionAudioBridge.makeNearSilentWAV(sampleRate: 8_000, duration: 1)

        #expect(String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: bytes[8..<12], as: UTF8.self) == "WAVE")
        #expect(String(decoding: bytes[36..<40], as: UTF8.self) == "data")
        #expect(bytes.count == 44 + 8_000 * 2)
    }

    @Test func keepsAnchorSignalEffectivelySilentButNonZero() {
        let bytes = PlaybackSessionAudioBridge.makeNearSilentWAV(sampleRate: 100, duration: 0.1)
        let first = Int16(bitPattern: UInt16(bytes[44]) | UInt16(bytes[45]) << 8)
        let second = Int16(bitPattern: UInt16(bytes[46]) | UInt16(bytes[47]) << 8)

        #expect(abs(Int(first)) == 1)
        #expect(abs(Int(second)) == 1)
    }
}
