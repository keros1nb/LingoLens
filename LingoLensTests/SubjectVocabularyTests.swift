import Foundation
import Testing
@testable import LingoLens

struct SubjectVocabularyTests {
    private func vector(_ value: Float) -> [Float] {
        [value] + [Float](repeating: 0, count: SubjectVocabulary.dimension - 1)
    }

    @Test func selectsThreeBestNames() {
        let names = ["headphones", "door", "sock", "monitor"]
        let rows = [vector(0.6), vector(0.9), vector(0.8), vector(0.7)]
            + Array(repeating: vector(0), count: SubjectVocabulary.backgroundCount)
        let vocabulary = SubjectVocabulary(names: names, embeddings: rows.flatMap { $0 })
        #expect(vocabulary.candidates(for: vector(1)).map(\.englishName) == ["door", "sock", "monitor"])
    }

    @Test func backgroundImageDoesNotInventAnObject() {
        let rows = [vector(0.3), vector(0.8)]
            + Array(repeating: vector(0), count: SubjectVocabulary.backgroundCount - 1)
        let vocabulary = SubjectVocabulary(names: ["headphones"], embeddings: rows.flatMap { $0 })
        #expect(vocabulary.candidates(for: vector(1)).isEmpty)
    }

    @Test func weakSimilarityDoesNotOfferAWord() {
        let rows = [vector(0.19)] + Array(repeating: vector(0), count: SubjectVocabulary.backgroundCount)
        let vocabulary = SubjectVocabulary(names: ["door"], embeddings: rows.flatMap { $0 })
        #expect(vocabulary.candidates(for: vector(1)).isEmpty)
    }

    @Test func bundledVocabularyIncludesReportedObjects() throws {
        let vocabulary = try SubjectVocabulary(directory: Bundle.main.bundleURL)
        #expect(vocabulary.names.count > 1000)
        for name in ["headphones", "door", "sock", "rug", "monitor"] {
            #expect(vocabulary.names.contains(name))
        }
    }
}
