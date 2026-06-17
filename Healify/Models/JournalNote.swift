import Foundation
import SwiftData

/// A structured journal note attached to a wound.
@Model
final class JournalNote {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var text: String
    /// Optional subjective pain, 0 (none) – 10 (worst). Nil = not recorded.
    var painLevel: Int?
    var symptoms: [Symptom]
    var isClinicianGuidance: Bool
    /// Doctor's expected time-to-heal in days; anchors the projection when set.
    var expectedHealingDays: Int?

    var wound: Wound?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        text: String = "",
        painLevel: Int? = nil,
        symptoms: [Symptom] = [],
        isClinicianGuidance: Bool = false,
        expectedHealingDays: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.painLevel = painLevel
        self.symptoms = symptoms
        self.isClinicianGuidance = isClinicianGuidance
        self.expectedHealingDays = expectedHealingDays
    }
}

enum Symptom: String, Codable, CaseIterable, Identifiable {
    case redness
    case swelling
    case warmth
    case drainage
    case odor
    case itching
    case bleeding
    case fever

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .redness: return "drop.fill"
        case .swelling: return "circle.circle"
        case .warmth: return "thermometer.medium"
        case .drainage: return "drop.triangle"
        case .odor: return "wind"
        case .itching: return "hand.point.up.braille"
        case .bleeding: return "bandage.fill"
        case .fever: return "thermometer.sun.fill"
        }
    }

    /// Symptoms that commonly signal infection — surfaced as a gentle warning.
    var isInfectionFlag: Bool {
        switch self {
        case .warmth, .drainage, .odor, .fever: return true
        default: return false
        }
    }
}
