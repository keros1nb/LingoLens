import AVFoundation
import Observation

enum CameraStatus {
    case permissionRequired, denied, stopped, starting, ready, unavailable, failed
}

@MainActor @Observable
final class CameraService {
    private let capture = CameraSession()
    private var activationID = UUID()
    private(set) var status: CameraStatus = .permissionRequired
    private(set) var isCapturing = false
    var session: AVCaptureSession { capture.session }

    func activate(requestPermission: Bool = false) async {
        let current = UUID()
        activationID = current
        var permission = AVCaptureDevice.authorizationStatus(for: .video)
        if permission == .notDetermined {
            guard requestPermission else { status = .permissionRequired; return }
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            permission = allowed ? .authorized : .denied
        }
        guard current == activationID, !Task.isCancelled else { return }
        guard permission == .authorized else { status = .denied; return }
        status = .starting
        do {
            try await capture.start()
            guard current == activationID, !Task.isCancelled else { return }
            status = .ready
        } catch {
            guard current == activationID, !Task.isCancelled else { return }
            if case CameraError.unavailable = error { status = .unavailable }
            else { status = .failed }
        }
    }

    func stop() {
        activationID = UUID()
        status = .stopped
        capture.stop()
    }

    func takePhoto() async throws -> Data {
        guard status == .ready, !isCapturing else { throw CameraError.notReady }
        isCapturing = true
        defer { isCapturing = false }
        return try await capture.takePhoto()
    }
}

enum CameraError: Error { case unavailable, notReady, captureFailed }

// Session configuration, capture state and delegate results are confined to this serial queue.
final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.lingolens.camera")
    private let output = AVCapturePhotoOutput()
    private var isConfigured = false
    private var pendingPhoto: CheckedContinuation<Data, any Error>?

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                do {
                    if !self.isConfigured {
                        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                            throw CameraError.unavailable
                        }
                        let input = try AVCaptureDeviceInput(device: device)
                        self.session.beginConfiguration()
                        self.session.sessionPreset = .photo
                        guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                            self.session.commitConfiguration()
                            throw CameraError.unavailable
                        }
                        self.session.addInput(input)
                        self.session.addOutput(self.output)
                        self.session.commitConfiguration()
                        self.isConfigured = true
                    }
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func takePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.session.isRunning, self.pendingPhoto == nil else {
                    continuation.resume(throwing: CameraError.notReady)
                    return
                }
                self.pendingPhoto = continuation
                if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                self.output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async {
            guard let continuation = self.pendingPhoto else { return }
            self.pendingPhoto = nil
            if let data { continuation.resume(returning: data) }
            else { continuation.resume(throwing: CameraError.captureFailed) }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: (any Error)?) {
        guard error != nil else { return }
        queue.async {
            self.pendingPhoto?.resume(throwing: CameraError.captureFailed)
            self.pendingPhoto = nil
        }
    }
}
