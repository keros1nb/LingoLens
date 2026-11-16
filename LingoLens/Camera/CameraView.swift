import SwiftUI

struct CameraView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var camera = CameraService()
    @State private var model = AppEnvironment.captureModel()
    @State private var isVisible = false
    @State private var showingResult = false
    @State private var captureError: String?
    @State private var captureTask: Task<Void, Never>?
    #if DEBUG
    @State private var didAutoCapture = false
    #endif

    private var cameraIsActive: Bool { isVisible && scenePhase == .active && !showingResult }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("РУССКИЙ → АНГЛИЙСКИЙ")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.accent)
                    Text("Новые слова рядом")
                        .font(.title.bold())
                    Text("Поместите один предмет в центр кадра")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                viewfinder
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay {
                        if camera.status == .ready || AppEnvironment.isUITesting {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [12, 8]))
                                .frame(width: 160, height: 160)
                                .accessibilityHidden(true)
                        }
                    }

                Button(action: capturePhoto) {
                    Label(camera.isCapturing ? "Снимаем…" : "Снять предмет", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(camera.isCapturing || (camera.status != .ready && !AppEnvironment.isUITesting))
                .accessibilityIdentifier("capturePhoto")
                .accessibilityLabel("Сфотографировать предмет")

                Text("Снимок обрабатывается на iPhone.\nВ словарь попадёт только то, что вы сохраните.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("LingoLens")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isVisible = true }
        .onDisappear {
            isVisible = false
            captureTask?.cancel()
            camera.stop()
        }
        .task(id: cameraIsActive) {
            if AppEnvironment.isUITesting {
                #if DEBUG
                if cameraIsActive && !didAutoCapture && ProcessInfo.processInfo.arguments.contains("--auto-capture") {
                    didAutoCapture = true
                    capturePhoto()
                }
                #endif
                return
            }
            if cameraIsActive { await camera.activate() }
            else { camera.stop() }
        }
        .sheet(isPresented: $showingResult, onDismiss: {
            captureTask?.cancel()
            model.reset()
        }) {
            ResultView(model: model) { showingResult = false }
                .presentationDragIndicator(.visible)
        }
        .alert("Не удалось сделать снимок", isPresented: Binding(
            get: { captureError != nil }, set: { if !$0 { captureError = nil } })) {
                Button("Понятно", role: .cancel) {}
            } message: { Text(captureError ?? "") }
    }

    @ViewBuilder private var viewfinder: some View {
        if AppEnvironment.isUITesting {
            Rectangle().fill(Theme.accent.opacity(0.2))
                .overlay { Image(systemName: "cup.and.saucer").font(.system(size: 70)).foregroundStyle(Theme.accent) }
        } else {
            ZStack {
                // Preserve the preview connection while capture is paused. Rebuilding
                // it during session transitions can block the main thread.
                CameraPreview(session: camera.session)
                    .opacity(camera.status == .ready ? 1 : 0)
                    .accessibilityHidden(camera.status != .ready)
                if camera.status != .ready {
                    Rectangle().fill(.quaternary).overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "camera").font(.largeTitle).foregroundStyle(Theme.accent)
                            switch camera.status {
                            case .permissionRequired:
                                Text("Камера поможет найти слово").font(.headline)
                                Text("Разрешите доступ, чтобы фотографировать предметы.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Button("Разрешить камеру") { Task { await camera.activate(requestPermission: true) } }
                                    .buttonStyle(.bordered).controlSize(.large)
                                    .accessibilityIdentifier("allowCamera")
                            case .denied:
                                Text("Разрешите доступ к камере").font(.headline)
                                Button("Открыть настройки") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }.buttonStyle(.bordered).controlSize(.large)
                            case .starting, .stopped:
                                ProgressView("Включаем камеру…")
                            case .unavailable:
                                Text("Камера недоступна").font(.headline)
                                Text("Для съёмки нужен iPhone с доступной задней камерой.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            case .failed:
                                Text("Не удалось включить камеру").font(.headline)
                                Button("Повторить") { Task { await camera.activate() } }
                                    .buttonStyle(.bordered).controlSize(.large)
                            case .ready: EmptyView()
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(24)
                    }
                }
            }
        }
    }

    private func capturePhoto() {
        captureTask = Task {
            do {
                let data: Data
                #if DEBUG
                if AppEnvironment.isUITesting { data = AppEnvironment.fixturePhoto }
                else { data = try await camera.takePhoto() }
                #else
                data = try await camera.takePhoto()
                #endif
                try Task.checkCancellation()
                showingResult = true
                await model.analyze(data)
            } catch is CancellationError { return }
            catch { captureError = "Проверьте, что камера доступна, и попробуйте ещё раз." }
        }
    }
}
