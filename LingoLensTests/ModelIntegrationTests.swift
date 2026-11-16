import Testing
import UIKit
@testable import LingoLens

struct ModelIntegrationTests {
    @Test @MainActor func bundledDetectorProcessesBlankPhoto() async throws {
        let data = UIGraphicsImageRenderer(size: CGSize(width: 416, height: 416))
            .jpegData(withCompressionQuality: 0.9) { renderer in
                UIColor.white.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 416, height: 416))
            }
        let service = RecognitionService()
        let result = try await service.recognize(imageData: data)
        #expect(result.isEmpty)
    }
}
