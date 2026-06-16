import SwiftUI
import SwiftData

@main
struct HealifyApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var healingService = HealingService()
    @StateObject private var healthProfile = HealthProfileService()

    /// Single shared SwiftData container for the whole app.
    let container: ModelContainer = {
        let schema = Schema([Wound.self, WoundPhoto.self, JournalNote.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
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
