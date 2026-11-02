import Foundation
import Vision

actor RecognitionService {
    static let revision = VNClassifyImageRequestRevision2

    func recognize(imageData: Data) throws -> [RecognitionCandidate] {
        let request = VNClassifyImageRequest()
        request.revision = Self.revision
        let handler = VNImageRequestHandler(data: imageData, options: [:])
        try handler.perform([request])
        return RecognitionCandidate.topThree(from: (request.results ?? []).map {
            RecognitionCandidate(identifier: $0.identifier, confidence: $0.confidence)
        })
    }
}
