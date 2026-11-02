import PhotosUI
import SwiftUI

/// Diagnostic screen for the recognition quality gate, before the main app UI.
struct RecognitionProbeView: View {
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var candidates: [RecognitionCandidate] = []
    @State private var isRecognizing = false
    @State private var errorMessage: String?
    private let recognition = RecognitionService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Проверка распознавания", systemImage: "viewfinder")
                        .font(.title2.bold())
                    Text("Это диагностическая сборка. Основной интерфейс появится после проверки качества названий предметов.")
                        .foregroundStyle(.secondary)

                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Фотография для проверки")
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Проверить фотографию", systemImage: "photo")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("chooseDiagnosticPhoto")
                    .disabled(isRecognizing)

                    if isRecognizing {
                        ProgressView("Распознаём предмет…")
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("recognitionError")
                    }
                    ForEach(candidates) { candidate in
                        HStack {
                            Text(candidate.englishName)
                                .font(.headline)
                            Spacer()
                            Text(candidate.confidence, format: .percent.precision(.fractionLength(0)))
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("Фото обрабатывается на устройстве и не сохраняется приложением. Если название не подходит, попробуйте другое фото.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("LingoLens")
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                isRecognizing = true
                errorMessage = nil
                candidates = []
                photoData = nil
                defer { isRecognizing = false }
                do {
                    guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                        errorMessage = "Не удалось прочитать фото. Выберите другое изображение."
                        return
                    }
                    try Task.checkCancellation()
                    photoData = data
                    let result = try await recognition.recognize(imageData: data)
                    try Task.checkCancellation()
                    candidates = result
                    if result.isEmpty {
                        errorMessage = "Нет вариантов названия. Попробуйте другое фото."
                    }
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = "Не удалось распознать предмет. Попробуйте другое фото."
                }
            }
        }
        .tint(.green)
    }
}
