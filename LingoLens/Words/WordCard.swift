import Foundation
import SwiftData

@Model
final class WordCard {
    var id: UUID
    @Attribute(.unique) var englishKey: String
    var englishName: String
    var russianTranslation: String
    @Attribute(.externalStorage) var photoData: Data
    var savedAt: Date

    init(englishName: String, russianTranslation: String, photoData: Data) {
        id = UUID()
        englishKey = RecognitionCandidate.normalizedName(englishName)
        self.englishName = englishName
        self.russianTranslation = russianTranslation
        self.photoData = photoData
        savedAt = Date()
    }
}

@MainActor
enum WordCardStore {
    static func save(englishName: String, translation: String, photoData: Data,
                     in context: ModelContext) throws -> WordCard {
        let key = RecognitionCandidate.normalizedName(englishName)
        var request = FetchDescriptor<WordCard>(predicate: #Predicate { $0.englishKey == key })
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first { return existing }
        let card = WordCard(englishName: englishName, russianTranslation: translation, photoData: photoData)
        context.insert(card)
        do {
            try context.save()
            return card
        } catch {
            context.rollback()
            throw error
        }
    }

    static func delete(_ card: WordCard, in context: ModelContext) throws {
        context.delete(card)
        do { try context.save() }
        catch {
            context.rollback()
            throw error
        }
    }
}
