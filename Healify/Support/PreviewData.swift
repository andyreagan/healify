import Foundation
import SwiftData

/// In-memory sample data for SwiftUI previews.
enum PreviewData {
    @MainActor
    static let container: ModelContainer = {
        let schema = Schema([Wound.self, WoundPhoto.self, JournalNote.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let knee = Wound(name: "Knee scrape", bodyLocation: "left knee", kind: .abrasion,
                         createdAt: .now.addingTimeInterval(-12 * 86_400))
        context.insert(knee)

        let n1 = JournalNote(timestamp: .now.addingTimeInterval(-11 * 86_400),
                             text: "Cleaned and dressed. Stings a bit.", painLevel: 5,
                             symptoms: [.redness, .swelling])
        n1.wound = knee
        let n2 = JournalNote(timestamp: .now.addingTimeInterval(-9 * 86_400),
                             text: "Doctor says keep it covered; should close in about two weeks.",
                             painLevel: 3, isClinicianGuidance: true, expectedHealingDays: 14)
        n2.wound = knee
        knee.notes.append(contentsOf: [n1, n2])

        let surgical = Wound(name: "Appendectomy incision", bodyLocation: "lower right abdomen",
                             kind: .surgical, createdAt: .now.addingTimeInterval(-5 * 86_400))
        context.insert(surgical)

        return container
    }()
}
