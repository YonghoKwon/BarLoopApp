import Testing
@testable import BarLoopCore

@Suite("BPM input helpers")
struct BPMTests {
    @Test func removesLeadingZerosWhileTyping() {
        #expect(PracticeMath.normalizeBPMText("088") == "88")
        #expect(PracticeMath.normalizeBPMText("000120") == "120")
    }

    @Test func keepsEmptyDraftEditable() {
        #expect(PracticeMath.normalizeBPMText("") == "")
        #expect(PracticeMath.normalizeBPMText("abc") == "")
    }

    @Test func removesNonNumericCharactersAndClampsMaximum() {
        #expect(PracticeMath.normalizeBPMText("1a2b0") == "120")
        #expect(PracticeMath.normalizeBPMText("999") == "400")
    }

    @Test func clampsCommittedValuesToSupportedRange() {
        #expect(PracticeMath.clampBPM(5) == 20)
        #expect(PracticeMath.clampBPM(88.4) == 88)
        #expect(PracticeMath.clampBPM(900) == 400)
    }

    @Test func usesPreviousValueForEmptyDraft() {
        #expect(PracticeMath.parseBPMText("", fallback: 96) == 96)
    }
}
