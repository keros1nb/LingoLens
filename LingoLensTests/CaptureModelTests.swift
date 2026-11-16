import Foundation
import Testing
@testable import LingoLens

@MainActor
struct CaptureModelTests {
    private let cup = RecognitionCandidate(identifier: "cup", confidence: 0.9)
    private let chair = RecognitionCandidate(identifier: "chair", confidence: 0.7)

    @Test func choosesFirstCandidateAndRetainsPhoto() async {
        let candidates = [cup, chair]
        let model = CaptureModel { _ in candidates }
        await model.analyze(Data([1, 2]))
        #expect(model.selectedCandidate == cup)
        #expect(model.photoData == Data([1, 2]))
        #expect(model.candidates == candidates)
        #expect(!model.isRecognizing)
    }

    @Test func noDetectionOffersRetake() async {
        let model = CaptureModel { _ in [] }
        await model.analyze(Data([1]))
        #expect(model.selectedCandidate == nil)
        #expect(model.recognitionError != nil)
        #expect(!model.isRecognizing)
    }

    @Test func recognitionFailureCanBeRetried() async {
        actor Attempts {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let attempts = Attempts()
        let candidate = cup
        let model = CaptureModel { _ in
            if await attempts.next() == 1 { throw CameraError.captureFailed }
            return [candidate]
        }
        await model.analyze(Data([1]))
        #expect(model.recognitionError != nil)
        #expect(!model.isRecognizing)
        await model.analyze(Data([2]))
        #expect(model.recognitionError == nil)
        #expect(model.selectedCandidate == cup)
    }

    @Test func lateTranslationCannotOverwriteNewSelection() async {
        let candidates = [cup, chair]
        let model = CaptureModel { _ in candidates }
        await model.analyze(Data([1]))
        await model.translate { _ in
            model.select(chair)
            return "чашка"
        }
        #expect(model.selectedCandidate == chair)
        #expect(model.russianTranslation == nil)
        #expect(!model.isTranslating)
        await model.translate { _ in "стул" }
        #expect(model.russianTranslation == "стул")
    }

    @Test func translationFailurePreservesEnglishAndCanRetry() async {
        let candidate = cup
        let model = CaptureModel { _ in [candidate] }
        await model.analyze(Data([1]))
        await model.translate { _ in throw CameraError.captureFailed }
        #expect(model.selectedCandidate == cup)
        #expect(model.translationError != nil)
        #expect(!model.isTranslating)
        await model.translate { _ in "чашка" }
        #expect(model.translationError == nil)
        #expect(model.russianTranslation == "чашка")
    }

    @Test func resettingPhotoInvalidatesPendingTranslation() async {
        let candidate = cup
        let model = CaptureModel { _ in [candidate] }
        await model.analyze(Data([1]))
        await model.translate { _ in
            model.reset()
            return "чашка"
        }
        #expect(model.photoData == nil)
        #expect(model.candidates.isEmpty)
        #expect(model.russianTranslation == nil)
        #expect(!model.isTranslating)
    }

    @Test func olderTranslationCannotReplaceRetryForSameWord() async throws {
        let candidate = cup
        let model = CaptureModel { _ in [candidate] }
        await model.analyze(Data([1]))
        let first = try #require(model.beginTranslation())
        let retry = try #require(model.beginTranslation())
        model.finishTranslation(.success("старый ответ"), id: first.id)
        #expect(model.russianTranslation == nil)
        #expect(model.isTranslating)
        model.finishTranslation(.success("чашка"), id: retry.id)
        #expect(model.russianTranslation == "чашка")
        #expect(!model.isTranslating)
    }

    @Test func cancellationStopsTranslationLoading() async throws {
        let candidate = cup
        let model = CaptureModel { _ in [candidate] }
        await model.analyze(Data([1]))
        let request = try #require(model.beginTranslation())
        model.cancelTranslation(id: request.id)
        #expect(!model.isTranslating)
        #expect(model.translationError == nil)
        #expect(model.selectedCandidate == cup)
    }
}
