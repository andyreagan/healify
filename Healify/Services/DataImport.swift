import Foundation
import SwiftData

/// Restores a journal from a `DataExport` backup. Wounds whose id already exists
/// are skipped (idempotent); images are written under fresh filenames.
@MainActor
enum DataImport {
    struct Summary {
        var woundsAdded = 0
        var woundsSkipped = 0
        var photosAdded = 0
        var notesAdded = 0
    }

    enum ImportError: LocalizedError {
        case unreadable
        case badFormat
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Couldn't read the backup file."
            case .badFormat: return "This doesn't look like a Healify backup."
            case .unsupportedVersion(let v): return "This backup (format \(v)) is newer than this app supports."
            }
        }
    }

    static func restore(from url: URL, into context: ModelContext) throws -> Summary {
        // Files from the document picker are security-scoped.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let bundle = try? decoder.decode(DataExport.Bundle.self, from: data) else {
            throw ImportError.badFormat
        }
        guard bundle.formatVersion <= DataExport.formatVersion else {
            throw ImportError.unsupportedVersion(bundle.formatVersion)
        }

        let existingIDs = Set((try? context.fetch(FetchDescriptor<Wound>()))?.map(\.id) ?? [])

        var summary = Summary()
        for dto in bundle.wounds {
            guard !existingIDs.contains(dto.id) else { summary.woundsSkipped += 1; continue }

            let wound = Wound(
                id: dto.id,
                name: dto.name,
                bodyLocation: dto.bodyLocation,
                bodyRegion: dto.bodyRegion,
                kind: WoundKind(rawValue: dto.kind) ?? .other,
                createdAt: dto.createdAt,
                isArchived: dto.isArchived,
                targetScore: dto.targetScore
            )
            context.insert(wound)

            for p in dto.photos {
                // Recreate the image file from the embedded bytes under a new name.
                guard let b64 = bundle.images[p.imageFilename],
                      let bytes = Data(base64Encoded: b64),
                      let newName = try? ImageStore.saveOriginalData(bytes) else { continue }
                let photo = WoundPhoto(
                    id: p.id,
                    imageFilename: newName,
                    captureDate: p.captureDate,
                    exifCaptureDate: p.exifCaptureDate,
                    captureDateAdjusted: p.captureDateAdjusted,
                    addedAt: p.addedAt,
                    caption: p.caption
                )
                photo.healingScore = p.healingScore
                photo.rednessIndex = p.rednessIndex
                photo.wound = wound
                wound.photos.append(photo)
                context.insert(photo)
                summary.photosAdded += 1
            }

            for n in dto.notes {
                let note = JournalNote(
                    id: n.id,
                    timestamp: n.timestamp,
                    text: n.text,
                    painLevel: n.painLevel,
                    symptoms: n.symptoms.compactMap(Symptom.init(rawValue:)),
                    isClinicianGuidance: n.isClinicianGuidance,
                    expectedHealingDays: n.expectedHealingDays
                )
                note.wound = wound
                wound.notes.append(note)
                context.insert(note)
                summary.notesAdded += 1
            }
            summary.woundsAdded += 1
        }

        try context.save()
        return summary
    }
}
