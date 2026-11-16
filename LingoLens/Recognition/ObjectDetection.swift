import CoreGraphics
import Foundation

struct ObjectDetection {
    let identifier: String
    let confidence: Float
    let boundingBox: CGRect

    var candidate: RecognitionCandidate {
        let names = ["pottedplant": "potted plant", "diningtable": "dining table",
                     "tvmonitor": "television", "remote": "remote control"]
        return RecognitionCandidate(identifier: names[identifier] ?? identifier, confidence: confidence)
    }

    static func combined(subjects: [RecognitionCandidate], detections: [ObjectDetection]) -> [RecognitionCandidate] {
        let detected = detections.filter { $0.identifier != "person" && $0.confidence >= 0.25 }.sorted {
            let firstCentered = $0.boundingBox.contains(CGPoint(x: 0.5, y: 0.5))
            let secondCentered = $1.boundingBox.contains(CGPoint(x: 0.5, y: 0.5))
            if firstCentered != secondCentered { return firstCentered }
            return $0.confidence > $1.confidence
        }.map(\.candidate)
        var result = Array(subjects.prefix(2))
        // Detector confidence and CLIP similarity are different scales. Reserve
        // one choice for a localized object rather than comparing these scores.
        for candidate in detected + subjects.dropFirst(2) {
            if result.count == 3 { break }
            if !result.contains(where: { $0.englishName == candidate.englishName }) { result.append(candidate) }
        }
        return result
    }
}
