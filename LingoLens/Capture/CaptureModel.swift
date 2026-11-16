import Foundation
import Observation

@MainActor @Observable
final class CaptureModel {
    private let recognize: @Sendable (Data) async throws -> [RecognitionCandidate]
    private var generation = UUID()
    private var translationGeneration = UUID()
    private(set) var photoData: Data?
    private(set) var candidates: [RecognitionCandidate] = []
    private(set) var selectedCandidate: RecognitionCandidate?
    private(set) var russianTranslation: String?
    private(set) var isRecognizing = false
    private(set) var isTranslating = false
    private(set) var recognitionError: String?
    private(set) var translationError: String?
    #if DEBUG
    private(set) var translationDiagnostic: String?
    #endif

    init(recognize: @escaping @Sendable (Data) async throws -> [RecognitionCandidate]) {
        self.recognize = recognize
    }

    convenience init() {
        let service = RecognitionService()
        self.init { try await service.recognize(imageData: $0) }
    }

    func analyze(_ data: Data) async {
        reset()
        let current = generation
        photoData = data
        isRecognizing = true
        defer { if current == generation { isRecognizing = false } }
        do {
            let result = try await recognize(data)
            guard current == generation, !Task.isCancelled else { return }
            candidates = result
            selectedCandidate = result.first
            if result.isEmpty {
                recognitionError = "Предмет не найден. Поднесите его ближе к центру и сделайте новый снимок."
            }
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            recognitionError = "Не удалось распознать предмет. Попробуйте ещё раз или сделайте новый снимок."
        }
    }

    func select(_ candidate: RecognitionCandidate) {
        guard candidates.contains(candidate), candidate.id != selectedCandidate?.id else { return }
        selectedCandidate = candidate
        translationGeneration = UUID()
        russianTranslation = nil
        translationError = nil
        #if DEBUG
        translationDiagnostic = nil
        #endif
        isTranslating = false
    }

    func translate(using operation: (String) async throws -> String) async {
        guard let request = beginTranslation() else { return }
        do {
            let translation = try await operation(request.text)
            if Task.isCancelled { cancelTranslation(id: request.id) }
            else { finishTranslation(.success(translation), id: request.id) }
        } catch {
            if Task.isCancelled { cancelTranslation(id: request.id) }
            else { finishTranslation(.failure(error), id: request.id) }
        }
    }

    func beginTranslation() -> (id: UUID, text: String)? {
        guard let candidate = selectedCandidate else { return nil }
        translationGeneration = UUID()
        isTranslating = true
        translationError = nil
        return (translationGeneration, candidate.englishName)
    }

    func finishTranslation(_ result: Result<String, any Error>, id: UUID) {
        guard id == translationGeneration else { return }
        isTranslating = false
        switch result {
        case .success(let text): russianTranslation = text
        case .failure(let error):
            #if DEBUG
            translationDiagnostic = String(reflecting: error)
            print("[LingoLens] Translation failed: \(String(reflecting: error))")
            #endif
            translationError = "Перевод недоступен. Для первой загрузки языков нужен интернет. Попробуйте ещё раз."
        }
    }

    func cancelTranslation(id: UUID) {
        if id == translationGeneration { isTranslating = false }
    }

    func reset() {
        generation = UUID()
        translationGeneration = UUID()
        photoData = nil
        candidates = []
        selectedCandidate = nil
        russianTranslation = nil
        recognitionError = nil
        translationError = nil
        isRecognizing = false
        isTranslating = false
    }
}
