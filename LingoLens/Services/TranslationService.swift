import Foundation
import Translation

struct TranslationService {
    static func translate(_ text: String, using session: TranslationSession) async throws -> String {
        let availability = await LanguageAvailability().status(
            from: Locale.Language(identifier: "en"), to: Locale.Language(identifier: "ru"))
        #if DEBUG
        print("[LingoLens] Language availability: \(availability)")
        #endif
        guard availability != .unsupported else { throw TranslationError.unsupportedLanguagePairing }
        if availability == .supported { try await session.prepareTranslation() }
        #if DEBUG
        print("[LingoLens] Starting native translation")
        #endif
        return try await session.translate(text).targetText
    }
}
