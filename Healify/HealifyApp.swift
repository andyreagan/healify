import SwiftUI
import SwiftData

@main
struct HealifyApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var healingService = HealingService()
    @StateObject private var healthProfile = HealthProfileService()

    /// Single shared SwiftData container for the whole app, driven by a
    /// versioned schema + migration plan so user data survives schema changes.
    let container: ModelContainer = {
        let schema = Schema(versionedSchema: HealifySchemaV1.self)
        // Use an in-memory store under test: UI tests want a clean slate, and
        // unit tests host this app — its on-disk store is irrelevant to them and
        // can fail to create on a fresh CI simulator.
        let env = ProcessInfo.processInfo.environment
        let inMemory = env["HEALIFY_UITEST"] == "1" || env["XCTestConfigurationFilePath"] != nil
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, migrationPlan: HealifyMigrationPlan.self, configurations: config)
        } catch {
            // Crash rather than silently wiping: a failed migration should be
            // fixed in code (add a stage), never resolved by deleting the store.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(healingService)
                .environmentObject(healthProfile)
                .tint(.accentColor)
        }
        .modelContainer(container)
    }
}
