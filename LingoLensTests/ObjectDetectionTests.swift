import CoreGraphics
import Testing
@testable import LingoLens

struct ObjectDetectionTests {
    private let centered = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    private let subjects = ["headphones", "earbuds", "headset"].map { RecognitionCandidate(identifier: $0, confidence: 0.3) }

    @Test func keepsBroadNamesAndOneLocalizedChoice() {
        let detections = [ObjectDetection(identifier: "chair", confidence: 0.8, boundingBox: centered)]
        #expect(ObjectDetection.combined(subjects: subjects, detections: detections).map(\.englishName) == ["headphones", "earbuds", "chair"])
    }

    @Test func keepsThirdBroadNameWithoutValidDetection() {
        let detections = [ObjectDetection(identifier: "person", confidence: 0.9, boundingBox: centered),
                          ObjectDetection(identifier: "chair", confidence: 0.2, boundingBox: centered)]
        #expect(ObjectDetection.combined(subjects: subjects, detections: detections) == subjects)
    }

    @Test func prefersCenterAndDoesNotRepeatWords() {
        let detections = [ObjectDetection(identifier: "headphones", confidence: 0.95, boundingBox: centered),
                          ObjectDetection(identifier: "chair", confidence: 0.8, boundingBox: centered),
                          ObjectDetection(identifier: "bottle", confidence: 0.9, boundingBox: .zero)]
        #expect(ObjectDetection.combined(subjects: subjects, detections: detections).map(\.englishName) == ["headphones", "earbuds", "chair"])
    }

    @Test func usesDetectorWhenBroadModelHasNoCandidates() {
        let detections = [ObjectDetection(identifier: "pottedplant", confidence: 0.8, boundingBox: centered)]
        #expect(ObjectDetection.combined(subjects: [], detections: detections).map(\.englishName) == ["potted plant"])
    }
}
