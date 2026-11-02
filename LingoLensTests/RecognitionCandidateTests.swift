import Testing
@testable import LingoLens

struct RecognitionCandidateTests {
    @Test func normalizesIdentifiersForDisplay() {
        let candidate = RecognitionCandidate(identifier: "  Coffee_cup\n", confidence: 0.8)
        #expect(candidate.englishName == "coffee cup")
        #expect(candidate.id == "  Coffee_cup\n")
    }

    @Test func selectsThreeUniqueNamesByDescendingConfidence() {
        let input: [RecognitionCandidate] = [
            .init(identifier: "table", confidence: 0.2),
            .init(identifier: "coffee_cup", confidence: 0.9),
            .init(identifier: "coffee cup", confidence: 0.8),
            .init(identifier: "mug", confidence: 0.7),
            .init(identifier: "bottle", confidence: 0.6)
        ]
        let result = RecognitionCandidate.topThree(from: input)
        #expect(result.map(\.englishName) == ["coffee cup", "mug", "bottle"])
        #expect(result.first?.confidence == 0.9)
    }

    @Test func handlesEmptyOrUnusableResults() {
        #expect(RecognitionCandidate.topThree(from: []).isEmpty)
        #expect(RecognitionCandidate.topThree(from: [
            .init(identifier: "", confidence: 0.9),
            .init(identifier: "cup", confidence: 0),
            .init(identifier: "mug", confidence: .nan)
        ]).isEmpty)
    }

    @Test func equalConfidenceHasStableOrder() {
        let input: [RecognitionCandidate] = [
            .init(identifier: "table", confidence: 0.5),
            .init(identifier: "chair", confidence: 0.5)
        ]
        #expect(RecognitionCandidate.topThree(from: input).map(\.englishName) == ["chair", "table"])
    }
}
