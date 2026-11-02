import Foundation

struct RecognitionCandidate: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let englishName: String
    let confidence: Float

    init(identifier: String, confidence: Float) {
        id = identifier
        englishName = Self.normalizedName(identifier)
        self.confidence = confidence
    }

    static func normalizedName(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    static func topThree(from candidates: [Self]) -> [Self] {
        var names = Set<String>()
        return Array(candidates.filter {
            !$0.englishName.isEmpty && $0.confidence.isFinite && $0.confidence > 0
        }.sorted {
            if $0.confidence == $1.confidence { return $0.id < $1.id }
            return $0.confidence > $1.confidence
        }.filter {
            names.insert($0.englishName).inserted
        }.prefix(3))
    }
}
