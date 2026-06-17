import Foundation
import SwiftData

/// A single wound being tracked, each with its own photo journal and notes.
@Model
final class Wound {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Free-text detail refining the body-map location, e.g. "2cm below knee".
    var bodyLocation: String
    var bodyRegion: BodyRegion?
    var kind: WoundKind
    var createdAt: Date
    /// Archived wounds are treated as healed: hidden from the active list, kept
    /// for history.
    var isArchived: Bool
    /// Target healing score (0–100) for the timeline projection.
    var targetScore: Double

    @Relationship(deleteRule: .cascade, inverse: \WoundPhoto.wound)
    var photos: [WoundPhoto]

    @Relationship(deleteRule: .cascade, inverse: \JournalNote.wound)
    var notes: [JournalNote]

    init(
        id: UUID = UUID(),
        name: String,
        bodyLocation: String = "",
        bodyRegion: BodyRegion? = nil,
        kind: WoundKind = .other,
        createdAt: Date = .now,
        isArchived: Bool = false,
        targetScore: Double = 90
    ) {
        self.id = id
        self.name = name
        self.bodyLocation = bodyLocation
        self.bodyRegion = bodyRegion
        self.kind = kind
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.targetScore = targetScore
        self.photos = []
        self.notes = []
    }
}

extension Wound {
    /// Photos oldest-first by capture date — the chronological journal.
    var photosByDate: [WoundPhoto] {
        photos.sorted { $0.captureDate < $1.captureDate }
    }

    /// Notes newest-first for display.
    var notesByDate: [JournalNote] {
        notes.sorted { $0.timestamp > $1.timestamp }
    }

    /// Location label: structured region plus any free-text detail.
    var locationDescription: String {
        switch (bodyRegion, bodyLocation.isEmpty) {
        case let (region?, false): return "\(region.displayName) · \(bodyLocation)"
        case let (region?, true): return region.displayName
        case (nil, false): return bodyLocation
        case (nil, true): return ""
        }
    }

    var baselinePhoto: WoundPhoto? { photosByDate.first }
    var latestPhoto: WoundPhoto? { photosByDate.last }
    var latestScore: Double? { latestPhoto?.healingScore }
}

enum WoundKind: String, Codable, CaseIterable, Identifiable {
    case surgical
    case abrasion
    case laceration
    case burn
    case ulcer
    case bite
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .surgical: return "Surgical incision"
        case .abrasion: return "Abrasion / scrape"
        case .laceration: return "Laceration / cut"
        case .burn: return "Burn"
        case .ulcer: return "Ulcer"
        case .bite: return "Bite"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .surgical: return "cross.case"
        case .abrasion: return "bandage"
        case .laceration: return "scissors"
        case .burn: return "flame"
        case .ulcer: return "circle.dashed"
        case .bite: return "pawprint"
        case .other: return "cross.vial"
        }
    }
}
