import Foundation
import CoreML
import ImageIO
import Vision

actor RecognitionService {
    static let modelName = "SubjectImageEncoder"
    static let detectorName = "YOLOv3Int8LUT"
    private let modelURL: URL?
    private var model: VNCoreMLModel?
    private var vocabulary: SubjectVocabulary?
    private var detector: VNCoreMLModel?

    init(modelURL: URL? = nil) {
        self.modelURL = modelURL
    }

    func recognize(imageData: Data) throws -> [RecognitionCandidate] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            throw RecognitionError.invalidImage
        }
        if model == nil {
            guard let url = modelURL ?? Bundle.main.url(forResource: Self.modelName, withExtension: "mlmodelc") else {
                throw RecognitionError.modelUnavailable
            }
            let compiled = url.pathExtension == "mlmodelc" ? url : try MLModel.compileModel(at: url)
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            model = try VNCoreMLModel(for: MLModel(contentsOf: compiled, configuration: configuration))
            vocabulary = try SubjectVocabulary(directory: url.deletingLastPathComponent())
            guard let detectorURL = modelURL.map({ $0.deletingLastPathComponent().appendingPathComponent(Self.detectorName + ".mlmodel") })
                ?? Bundle.main.url(forResource: Self.detectorName, withExtension: "mlmodelc") else {
                throw RecognitionError.modelUnavailable
            }
            let compiledDetector = detectorURL.pathExtension == "mlmodelc" ? detectorURL : try MLModel.compileModel(at: detectorURL)
            detector = try VNCoreMLModel(for: MLModel(contentsOf: compiledDetector, configuration: configuration))
            detector?.featureProvider = DetectorThresholds()
        }
        guard let model, let vocabulary, let detector else { throw RecognitionError.modelUnavailable }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop
        let detectionRequest = VNCoreMLRequest(model: detector)
        detectionRequest.imageCropAndScaleOption = .scaleFit
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        let rawOrientation = (properties?[kCGImagePropertyOrientation as String] as? NSNumber)?.uint32Value ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        let handler = VNImageRequestHandler(data: imageData, orientation: orientation, options: [:])
        try handler.perform([request, detectionRequest])
        guard let values = (request.results as? [VNCoreMLFeatureValueObservation])?
            .first(where: { $0.featureName == "embedding" })?.featureValue.multiArrayValue,
              values.count == SubjectVocabulary.dimension else { throw RecognitionError.modelUnavailable }
        let subjects = vocabulary.candidates(for: (0..<values.count).map { values[$0].floatValue })
        let detections = (detectionRequest.results as? [VNRecognizedObjectObservation] ?? []).compactMap { observation -> ObjectDetection? in
            guard let label = observation.labels.first else { return nil }
            return ObjectDetection(identifier: label.identifier, confidence: label.confidence, boundingBox: observation.boundingBox)
        }
        return ObjectDetection.combined(subjects: subjects, detections: detections)
    }
}

private final class DetectorThresholds: MLFeatureProvider {
    let featureNames: Set<String> = ["iouThreshold", "confidenceThreshold"]

    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "iouThreshold": MLFeatureValue(double: 0.45)
        case "confidenceThreshold": MLFeatureValue(double: 0.25)
        default: nil
        }
    }
}

enum RecognitionError: LocalizedError {
    case invalidImage, modelUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Не удалось прочитать фотографию. Попробуйте сделать новый снимок."
        case .modelUnavailable: "Модель распознавания недоступна. Переустановите приложение."
        }
    }
}
