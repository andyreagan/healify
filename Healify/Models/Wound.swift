import Foundation
import SwiftData

/// A single wound being tracked. The core unit of the app: the user can have
/// several wounds at once, each with its own photo journal and notes.
@Model
final class Wound {
    /// Stable identifier, handy for diffing and for AI/analysis caches.
    @Attribute(.unique) var id: UUID
    var name: String
    /// Optional free-text detail to refine the body-map location, e.g. "2cm
    /// below the kneecap".
    var bodyLocation: String
    /// Structured anatomical location chosen on the body map.
    var bodyRegion: BodyRegion?
    var kind: WoundKind
    var createdAt: Date
    /// When archived, the wound is considered healed/closed and hidden from the
    /// active list, but kept for history.
    var isArchived: Bool
    /// Healing score (0–100) the user is aiming for before considering the
    /// wound resolved. Used by the timeline projection.
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
    /// Photos ordered by the (possibly user-adjusted) capture date — this is the
    /// chronological journal the rest of the app reasons about.
    var photosByDate: [WoundPhoto] {
        photos.sorted { $0.captureDate < $1.captureDate }
    }

    /// Notes newest-first for display.
    var notesByDate: [JournalNote] {
        notes.sorted { $0.timestamp > $1.timestamp }
    }

    /// Best label for the wound's location: structured region plus any detail.
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

    /// The most recent computed healing score, if AI scoring has run.
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
