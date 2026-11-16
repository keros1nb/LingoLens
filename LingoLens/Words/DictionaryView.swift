import SwiftData
import SwiftUI

struct DictionaryView: View {
    let onOpenCamera: () -> Void
    @Query(sort: \WordCard.savedAt, order: .reverse) private var cards: [WordCard]
    @Environment(\.modelContext) private var context
    @State private var deletionFailed = false

    var body: some View {
        Group {
            if cards.isEmpty {
                ContentUnavailableView {
                    Label("Слова из вашей жизни", systemImage: "books.vertical")
                } description: {
                    Text("Сфотографируйте предмет и сохраните его название. Здесь появится ваш личный словарь.")
                } actions: {
                    Button("Сфотографировать предмет", action: onOpenCamera)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
            } else {
                List {
                    ForEach(cards) { card in
                        NavigationLink {
                            WordDetailView(card: card)
                        } label: {
                            HStack(spacing: 16) {
                                WordPhoto(data: card.photoData)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(card.englishName).font(.headline)
                                    Text(card.russianTranslation).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .accessibilityIdentifier("word-\(card.englishKey)")
                        .swipeActions {
                            Button("Удалить", systemImage: "trash", role: .destructive) {
                                do { try WordCardStore.delete(card, in: context) }
                                catch { deletionFailed = true }
                            }
                        }
                        .listRowBackground(Theme.background)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        .navigationTitle("Мой словарь")
        .alert("Не удалось удалить слово", isPresented: $deletionFailed) {
            Button("Понятно", role: .cancel) {}
        } message: { Text("Попробуйте ещё раз. Карточка осталась в словаре.") }
    }
}
