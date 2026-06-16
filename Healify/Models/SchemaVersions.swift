import Foundation
import SwiftData

/// Versioned schema + migration plan for Healify's SwiftData store.
///
/// Why this exists: SwiftData auto-migrates *additive* changes (a new model, a
/// new optional property) without data loss. *Structural* changes — renaming or
/// retyping a property, adding a required property, changing a relationship —
/// will otherwise fail to open an existing store. Declaring versioned schemas
/// and a migration plan gives us a controlled place to add a `MigrationStage`
/// for each such change, so user data is preserved across refinements.
///
/// Discipline going forward:
///   • Prefer additive changes (new optional fields / new models). No work
///     needed — they migrate automatically.
///   • For any structural change: snapshot the current models into a new
///     `HealifySchemaVN`, bump `versionIdentifier`, and append a
///     `MigrationStage` (`.lightweight` for renames SwiftData can infer, or
///     `.custom` for data transforms). Never edit a shipped schema in place.
enum HealifySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Wound.self, WoundPhoto.self, JournalNote.self]
    }
}

enum HealifyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HealifySchemaV1.self]
    }

    /// One stage per shipped structural change. Empty today (V1 is the baseline).
    static var stages: [MigrationStage] {
        []
    }
}
