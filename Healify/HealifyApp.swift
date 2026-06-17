import SwiftUI
import SwiftData

@main
struct HealifyApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var healingService = HealingService()

    let container: ModelContainer = {
        let schema = Schema(versionedSchema: HealifySchemaV1.self)
        // In-memory under test: UI tests want a clean slate, and the unit-test
        // host doesn't need an on-disk store (which can fail on fresh CI sims).
        let env = ProcessInfo.processInfo.environment
        let inMemory = env["HEALIFY_UITEST"] == "1" || env["XCTestConfigurationFilePath"] != nil
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, migrationPlan: HealifyMigrationPlan.self, configurations: config)
        } catch {
            // Crash rather than silently wiping: fix a failed migration in code.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // True only when this process hosts unit tests (UI tests run separately).
    private var isHostingUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            if isHostingUnitTests {
                Color.clear // inert host; unit tests use their own containers
            } else {
                RootView()
                    .environmentObject(settings)
                    .environmentObject(healingService)
                    .tint(.accentColor)
            }
        }
        .modelContainer(container)
    }
}
