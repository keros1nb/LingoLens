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

}
