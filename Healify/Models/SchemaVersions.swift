import Foundation
import SwiftData

/// Versioned schema + migration plan for the SwiftData store. Additive changes
/// migrate automatically; for any structural change, snapshot the models into a
/// new `HealifySchemaVN`, bump the version, and append a `MigrationStage` — never
/// edit a shipped schema in place.
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

    // One stage per shipped structural change. Empty: V1 is the baseline.
    static var stages: [MigrationStage] { [] }
}
