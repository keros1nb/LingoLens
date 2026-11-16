import Foundation

struct SubjectVocabulary: Sendable {
    static let dimension = 512
    static let backgroundCount = 6
    let names: [String]
    let embeddings: [Float]

    init(names: [String], embeddings: [Float]) {
        self.names = names
        self.embeddings = embeddings
    }

    init(directory: URL) throws {
        names = try JSONDecoder().decode([String].self, from: Data(contentsOf: directory.appendingPathComponent("SubjectNames.json")))
        let data = try Data(contentsOf: directory.appendingPathComponent("SubjectEmbeddings.bin"))
        guard data.count == (names.count + Self.backgroundCount) * Self.dimension * MemoryLayout<Float>.size else {
            throw RecognitionError.modelUnavailable
        }
        embeddings = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    func candidates(for imageEmbedding: [Float]) -> [RecognitionCandidate] {
        guard imageEmbedding.count == Self.dimension else { return [] }
        var scores = [Float](repeating: 0, count: names.count + Self.backgroundCount)
        for index in scores.indices {
            let offset = index * Self.dimension
            var similarity: Float = 0
            for component in 0..<Self.dimension {
                similarity += embeddings[offset + component] * imageEmbedding[component]
            }
            scores[index] = similarity
        }
        let background = scores.suffix(Self.backgroundCount).max() ?? 0
        return Array(names.indices.filter { scores[$0] >= 0.20 && scores[$0] > background }.sorted {
            if scores[$0] == scores[$1] { return names[$0] < names[$1] }
            return scores[$0] > scores[$1]
        }.prefix(3).map { RecognitionCandidate(identifier: names[$0], confidence: scores[$0]) })
    }
}
