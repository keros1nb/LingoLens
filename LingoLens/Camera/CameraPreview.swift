import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class Preview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override var accessibilityValue: String? {
            get { previewLayer.isPreviewing ? "Камера включена" : "Камера выключена" }
            set {}
        }
    }

    func makeUIView(context: Context) -> Preview {
        let view = Preview()
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "cameraPreview"
        view.accessibilityLabel = "Видоискатель камеры"
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ view: Preview, context: Context) {
        if view.previewLayer.session !== session { view.previewLayer.session = session }
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}
