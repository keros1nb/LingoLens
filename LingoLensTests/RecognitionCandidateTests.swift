import Testing
@testable import LingoLens

struct RecognitionCandidateTests {
    @Test func normalizesIdentifiersForDisplay() {
        let candidate = RecognitionCandidate(identifier: "  Coffee_cup\n", confidence: 0.8)
        #expect(candidate.englishName == "coffee cup")
        #expect(candidate.id == "  Coffee_cup\n")
    }

}
