import SwiftData
import SwiftUI
import Translation

struct ResultView: View {
    let model: CaptureModel
    let onRetake: () -> Void
    @Environment(\.modelContext) private var context
    @State private var speech = SpeechService()
    @State private var configuration: TranslationSession.Configuration?
    @State private var openedCard: WordCard?
    @State private var saveError: String?
    @State private var retryTranslation = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let data = model.photoData {
                        WordPhoto(data: data)
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .accessibilityLabel("Сфотографированный предмет")
                            .accessibilityIdentifier("capturedPhoto")
                    }
                    if model.isRecognizing {
                        ProgressView("Ищем название предмета…").frame(maxWidth: .infinity)
                    } else if let error = model.recognitionError {
                        Text(error).foregroundStyle(.secondary).accessibilityIdentifier("recognitionError")
                        if let data = model.photoData {
                            Button("Повторить распознавание") { Task { await model.analyze(data) } }
                                .buttonStyle(.bordered).controlSize(.large)
                        }
                    } else if let selected = model.selectedCandidate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("АНГЛИЙСКИЙ").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                            Text(selected.englishName)
                                .font(.largeTitle.bold())
                                .accessibilityIdentifier("selectedWord")
                                
                            if let translation = model.russianTranslation {
                                Text(translation).font(.title2).foregroundStyle(.secondary)
                                    .accessibilityIdentifier("russianTranslation")
                            } else if model.isTranslating {
                                ProgressView("Переводим…")
                            }
                        }
                        if model.candidates.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Какой предмет вы сняли?").font(.subheadline).foregroundStyle(.secondary)
                                ForEach(model.candidates) { candidate in
                                    Button { model.select(candidate) } label: {
                                        HStack {
                                            Text(candidate.englishName)
                                            Spacer()
                                            Image(systemName: candidate.id == selected.id ? "checkmark.circle.fill" : "circle")
                                                .accessibilityHidden(true)
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(minHeight: 48)
                                        .background(Theme.accent.opacity(candidate.id == selected.id ? 0.14 : 0.05), in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .accessibilityIdentifier("candidate-\(candidate.id)")
                                    .accessibilityAddTraits(candidate.id == selected.id ? .isSelected : [])
                                }
                            }
                        }
                        if let error = model.translationError {
                            Text(error).font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier("translationError")
                                .accessibilityValue(translationAccessibilityValue)
                            Button("Повторить перевод") { retryTranslation += 1 }
                                .buttonStyle(.bordered).controlSize(.large)
                        }
                        Button { speech.speak(selected.englishName) } label: {
                            Label("Послушать произношение", systemImage: "speaker.wave.2")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                        .accessibilityIdentifier("speakWord")

                        Button(action: save) { Label("Сохранить в словарь", systemImage: "bookmark") }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(model.russianTranslation == nil)
                            .accessibilityIdentifier("saveWord")
                    }
                    Button("Сделать новый снимок", action: onRetake)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("retakePhoto")
                }
                .padding(24)
            }
            .background(Theme.background)
            .navigationTitle("Ваше новое слово")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть", action: onRetake) } }
            .onChange(of: model.selectedCandidate?.id, initial: true) { requestTranslation() }
            .onChange(of: retryTranslation) { requestTranslation() }
            .translationTask(configuration) { @Sendable session in
                guard let request = await model.beginTranslation() else { return }
                do {
                    let text = try await TranslationService.translate(request.text, using: session)
                    if Task.isCancelled { await model.cancelTranslation(id: request.id) }
                    else { await model.finishTranslation(.success(text), id: request.id) }
                } catch {
                    if Task.isCancelled { await model.cancelTranslation(id: request.id) }
                    else { await model.finishTranslation(.failure(error), id: request.id) }
                }
            }
            .sheet(item: $openedCard) { card in
                NavigationStack {
                    WordDetailView(card: card)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { openedCard = nil } } }
                }
            }
            .alert("Не удалось сохранить слово", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                    Button("Понятно", role: .cancel) {}
                } message: { Text(saveError ?? "") }
            .alert("Озвучка недоступна", isPresented: Binding(
                get: { speech.errorMessage != nil }, set: { if !$0 { speech.errorMessage = nil } })) {
                    Button("Понятно", role: .cancel) {}
                } message: { Text(speech.errorMessage ?? "") }
            .onDisappear { speech.stop() }
        }
        .tint(Theme.accent)
    }

    private func requestTranslation() {
        guard model.selectedCandidate != nil else { configuration = nil; return }
        #if DEBUG
        if AppEnvironment.isUITesting && !ProcessInfo.processInfo.arguments.contains("--native-translation") {
            Task {
                await model.translate { text in
                    if ProcessInfo.processInfo.arguments.contains("--translation-error") { throw CameraError.captureFailed }
                    return text == "cup" ? "чашка" : "стул"
                }
            }
            return
        }
        #endif
        #if targetEnvironment(simulator)
        Task { await model.translate { _ in throw TranslationError.internalError } }
        #else
        if configuration == nil {
            configuration = .init(source: Locale.Language(identifier: "en"), target: Locale.Language(identifier: "ru"))
        } else { configuration?.invalidate() }
        #endif
    }

    private var translationAccessibilityValue: String {
        #if DEBUG
        AppEnvironment.isUITesting ? model.translationDiagnostic ?? "" : ""
        #else
        ""
        #endif
    }

    private func save() {
        guard let candidate = model.selectedCandidate, let translation = model.russianTranslation,
              let photo = model.photoData else { return }
        do {
            openedCard = try WordCardStore.save(englishName: candidate.englishName, translation: translation,
                                                photoData: photo, in: context)
        } catch { saveError = "Проверьте свободное место на iPhone и попробуйте сохранить слово ещё раз." }
    }
}
