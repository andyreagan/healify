import SwiftData

enum Persistence {
    /// Delete a wound and its children explicitly — SwiftData's cascade rule has
    /// proven unreliable across OS versions, leaving orphaned rows.
    @MainActor
    static func delete(_ wound: Wound, from context: ModelContext) {
        for photo in wound.photos {
            ImageStore.delete(photo.imageFilename)
            context.delete(photo)
        }
        for note in wound.notes {
            context.delete(note)
        }
        context.delete(wound)
    }
}
