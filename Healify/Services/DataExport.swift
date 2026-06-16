import Foundation
import SwiftData

/// Exports the entire journal — structured data *and* image files — into a
/// single shareable `.zip`. This is the hard safety net: regardless of any
/// future schema change, the user can export, and we can restore from this
/// bundle. The archive is self-describing (`schemaVersion`) for future import.
@MainActor
enum DataExport {
    static let formatVersion = 1

    // MARK: Codable bundle

    struct Bundle: Codable {
        var formatVersion: Int
        var schemaVersion: String
        var exportedAt: Date
        var wounds: [WoundDTO]
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

    /// Builds the backup zip and returns its URL (in a temp dir). Caller presents
    /// a share sheet; the OS copies it wherever the user chooses.
    static func makeBackup(_ context: ModelContext) throws -> URL {
        let wounds = try context.fetch(FetchDescriptor<Wound>())
        let bundle = Bundle(
            formatVersion: formatVersion,
            schemaVersion: HealifySchemaV1.versionIdentifier.description,
            exportedAt: .now,
            wounds: wounds.map(makeDTO)
        )

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("HealifyBackup-\(UUID().uuidString)", isDirectory: true)
        let payload = work.appendingPathComponent("Healify Backup", isDirectory: true)
        let imagesDir = payload.appendingPathComponent("images", isDirectory: true)
        try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // data.json
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(bundle).write(to: payload.appendingPathComponent("data.json"), options: .atomic)

        // image files
        for wound in wounds {
            for photo in wound.photos {
                let src = ImageStore.url(for: photo.imageFilename)
                if fm.fileExists(atPath: src.path) {
                    try? fm.copyItem(at: src, to: imagesDir.appendingPathComponent(photo.imageFilename))
                }
            }
        }

        // Zip the payload folder using the OS coordinator (no third-party deps).
        return try zip(directory: payload, into: work)
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

    /// `NSFileCoordinator`'s `.forUploading` reading intent hands back a zipped
    /// copy of a directory — the standard dependency-free way to make a zip.
    private static func zip(directory: URL, into destDir: URL) throws -> URL {
        var coordinatorError: NSError?
        var thrown: Error?
        var result: URL?

        let stamp = ISO8601DateFormatter.filenameStamp()
        let finalURL = destDir.appendingPathComponent("Healify Backup \(stamp).zip")

        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinatorError) { zippedURL in
            do {
                try FileManager.default.copyItem(at: zippedURL, to: finalURL)
                result = finalURL
            } catch {
                thrown = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let thrown { throw thrown }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        return result
    }
}

private extension ISO8601DateFormatter {
    /// A filesystem-friendly timestamp like "2026-06-16 1430".
    static func filenameStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HHmm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: .now)
    }
}
