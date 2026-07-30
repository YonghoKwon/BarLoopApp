import BarLoopCore
import SwiftData
import SwiftUI

@main
struct BarLoopApp: App {
    @State private var environment = AppEnvironment()

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            StoredPracticeSession.self,
            StoredPracticeSection.self,
            StoredDrumPattern.self,
            StoredPracticeRoutine.self,
            StoredMediaAsset.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create BarLoop data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment)
                .preferredColorScheme(environment.appearance.colorScheme)
                .task {
                    await environment.prepare()
                }
        }
        .modelContainer(modelContainer)
    }
}

