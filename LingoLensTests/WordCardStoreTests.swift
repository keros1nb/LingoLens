import Foundation
import SwiftData
import Testing
@testable import LingoLens

@MainActor
struct WordCardStoreTests {
    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(for: WordCard.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func duplicateWordOpensOriginalCard() throws {
        let container = try memoryContainer()
        let context = container.mainContext
        let first = try WordCardStore.save(englishName: "cup", translation: "чашка", photoData: Data([1, 2]), in: context)
        let second = try WordCardStore.save(englishName: " CUP ", translation: "кружка", photoData: Data([3]), in: context)
        #expect(first.id == second.id)
        #expect(try context.fetchCount(FetchDescriptor<WordCard>()) == 1)
        #expect(second.russianTranslation == "чашка")
        #expect(second.photoData == Data([1, 2]))
    }

    @Test func deletingCardPersistsItsRemoval() throws {
        let container = try memoryContainer()
        let card = try WordCardStore.save(englishName: "chair", translation: "стул", photoData: Data([1]), in: container.mainContext)
        try WordCardStore.delete(card, in: container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<WordCard>()) == 0)
    }

    @Test func dictionaryAndPhotoSurviveReopeningStorage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("words.store")
        let originalID: UUID = try autoreleasepool {
            let configuration = ModelConfiguration(url: url)
            let container = try ModelContainer(for: WordCard.self, configurations: configuration)
            return try WordCardStore.save(englishName: "bottle", translation: "бутылка", photoData: Data([1, 2, 3]), in: container.mainContext).id
        }
        let reopened = try ModelContainer(for: WordCard.self, configurations: ModelConfiguration(url: url))
        let saved = try #require(reopened.mainContext.fetch(FetchDescriptor<WordCard>()).first)
        #expect(saved.id == originalID)
        #expect(saved.englishName == "bottle")
        #expect(saved.russianTranslation == "бутылка")
        #expect(saved.photoData == Data([1, 2, 3]))
    }
}
