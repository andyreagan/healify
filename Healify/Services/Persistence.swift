import SwiftData

/// Shared persistence helpers.
enum Persistence {
    /// Deletes a wound and all of its photos (and their image files) and notes.
    ///
    /// We delete children explicitly rather than relying solely on SwiftData's
    /// cascade rule, which has proven unreliable across OS versions — this keeps
    /// the store free of orphaned rows regardless.
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
