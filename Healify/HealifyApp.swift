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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
