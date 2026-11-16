import SwiftUI

enum AppEnvironment {
    static var testColorScheme: ColorScheme? {
        #if DEBUG
        isUITesting && ProcessInfo.processInfo.arguments.contains("--dark-mode") ? .dark : nil
        #else
        nil
        #endif
    }

    static var isUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }

    @MainActor
    static func captureModel() -> CaptureModel {
        #if DEBUG
        if isUITesting {
            let shouldFail = ProcessInfo.processInfo.arguments.contains("--recognition-error")
            return CaptureModel { _ in
                if shouldFail { throw CameraError.captureFailed }
                return [.init(identifier: "cup", confidence: 0.9), .init(identifier: "chair", confidence: 0.7)]
            }
        }
        #endif
        return CaptureModel()
    }

    #if DEBUG
    @MainActor static var fixturePhoto: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400)).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemGray6.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
            UIImage(systemName: "cup.and.saucer.fill")?
                .withTintColor(.darkGray, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 100, y: 100, width: 200, height: 200))
        }
    }
    #endif
}
