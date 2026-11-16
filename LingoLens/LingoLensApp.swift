import SwiftUI
import SwiftData

@main
struct LingoLensApp: App {
    private let storage: Result<ModelContainer, any Error>

    init() {
        storage = Result {
            let configuration: ModelConfiguration
            if AppEnvironment.isUITesting {
                configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            } else {
                let directory = URL.applicationSupportDirectory
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                configuration = ModelConfiguration(url: directory.appendingPathComponent("LingoLens.store"))
            }
            return try ModelContainer(for: WordCard.self, configurations: configuration)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch storage {
            case .success(let container):
                RootView().modelContainer(container).preferredColorScheme(AppEnvironment.testColorScheme)
            case .failure:
                ContentUnavailableView("Не удалось открыть словарь", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("Перезапустите приложение. Если ошибка повторится, освободите место на iPhone."))
            }
        }
    }
}
