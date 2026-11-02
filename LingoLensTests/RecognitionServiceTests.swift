import Foundation
import Testing
@testable import LingoLens

struct RecognitionServiceTests {
    @Test func corruptImageReturnsAnError() async {
        let service = RecognitionService()
        await #expect(throws: (any Error).self) {
            try await service.recognize(imageData: Data("not an image".utf8))
        }
    }
}
