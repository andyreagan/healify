import Foundation
import SwiftData

/// Exports/imports the entire journal as a single self-contained `.json` backup
/// with images embedded (base64). One file → trivial, dependency-free round-trip
/// (iOS has no built-in unzip), and a hard safety net independent of schema
/// migrations: even a full delete/reinstall or a new phone can be restored.
@MainActor
enum DataExport {
    static let formatVersion = 1
    static let fileExtension = "json"

    // MARK: Codable bundle

    struct Bundle: Codable {
        var formatVersion: Int
        var schemaVersion: String
        var exportedAt: Date
        var wounds: [WoundDTO]
        /// imageFilename → base64-encoded JPEG bytes.
        var images: [String: String]
    }

    struct WoundDTO: Codable {
        var id: UUID
        var name: String
        var bodyLocation: String
        var bodyRegion: BodyRegion?
        var kind: String
        var createdAt: Date
        var isArchived: Bool
        var targetScore: Double
        var photos: [PhotoDTO]
        var notes: [NoteDTO]
    }

    struct PhotoDTO: Codable {
        var id: UUID
        var imageFilename: String
        var captureDate: Date
        var exifCaptureDate: Date?
        var captureDateAdjusted: Bool
        var addedAt: Date
        var caption: String
        var healingScore: Double?
        var rednessIndex: Double?
    }

    struct NoteDTO: Codable {
        var id: UUID
        var timestamp: Date
        var text: String
        var painLevel: Int?
        var symptoms: [String]
        var isClinicianGuidance: Bool
        var expectedHealingDays: Int?
    }

    // MARK: Export

    /// Builds the backup file and returns its URL (in a temp dir). Caller
    /// presents a share sheet; the OS copies it wherever the user chooses.
    static func makeBackup(_ context: ModelContext) throws -> URL {
        let wounds = try context.fetch(FetchDescriptor<Wound>())

        var images: [String: String] = [:]
        for wound in wounds {
            for photo in wound.photos {
                if let data = ImageStore.loadData(photo.imageFilename) {
                    images[photo.imageFilename] = data.base64EncodedString()
                }
            }
        }

        let bundle = Bundle(
            formatVersion: formatVersion,
            schemaVersion: HealifySchemaV1.versionIdentifier.description,
            exportedAt: .now,
            wounds: wounds.map(makeDTO),
            images: images
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(bundle)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Healify Backup \(filenameStamp()).\(fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func makeDTO(_ w: Wound) -> WoundDTO {
        WoundDTO(
            id: w.id, name: w.name, bodyLocation: w.bodyLocation, bodyRegion: w.bodyRegion,
            kind: w.kind.rawValue, createdAt: w.createdAt, isArchived: w.isArchived, targetScore: w.targetScore,
            photos: w.photosByDate.map { p in
                PhotoDTO(id: p.id, imageFilename: p.imageFilename, captureDate: p.captureDate,
                         exifCaptureDate: p.exifCaptureDate, captureDateAdjusted: p.captureDateAdjusted,
                         addedAt: p.addedAt, caption: p.caption, healingScore: p.healingScore, rednessIndex: p.rednessIndex)
            },
            notes: w.notesByDate.map { n in
                NoteDTO(id: n.id, timestamp: n.timestamp, text: n.text, painLevel: n.painLevel,
                        symptoms: n.symptoms.map(\.rawValue), isClinicianGuidance: n.isClinicianGuidance,
                        expectedHealingDays: n.expectedHealingDays)
            }
        )
    }

    private static func filenameStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HHmm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: .now)
    }
}
