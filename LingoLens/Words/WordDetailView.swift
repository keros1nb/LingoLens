import SwiftUI

struct WordDetailView: View {
    let card: WordCard
    @State private var speech = SpeechService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WordPhoto(data: card.photoData)
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityLabel("Фото: \(card.russianTranslation)")
                VStack(alignment: .leading, spacing: 8) {
                    Text("В ВАШЕМ СЛОВАРЕ").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    Text(card.englishName).font(.largeTitle.bold())
                    Text(card.russianTranslation).font(.title2).foregroundStyle(.secondary)
                }
                Button { speech.speak(card.englishName) } label: {
                    Label("Послушать произношение", systemImage: "speaker.wave.2")
                }.buttonStyle(PrimaryButtonStyle())
            }.padding(24)
        }
        .background(Theme.background)
        .navigationTitle(card.englishName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("wordDetail")
        .onDisappear { speech.stop() }
        .alert("Озвучка недоступна", isPresented: Binding(
            get: { speech.errorMessage != nil }, set: { if !$0 { speech.errorMessage = nil } })) {
                Button("Понятно", role: .cancel) {}
            } message: { Text(speech.errorMessage ?? "") }
    }
}
