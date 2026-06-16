import SwiftUI

/// User preferences, persisted via `@AppStorage`. The AI scoring is strictly
/// opt-in and off by default, honoring the "opt-in, on-device" requirement.
final class AppSettings: ObservableObject {
    @AppStorage("aiScoringEnabled") var aiScoringEnabled: Bool = false
    /// Re-run analysis automatically whenever a photo is added (only matters
    /// while AI scoring is enabled).
    @AppStorage("autoAnalyzeOnAdd") var autoAnalyzeOnAdd: Bool = true
    /// One-time acknowledgement that scores are not medical advice.
    @AppStorage("aiDisclaimerAcknowledged") var aiDisclaimerAcknowledged: Bool = false

    /// Body-map silhouette, chosen manually in Settings (default neutral).
    @AppStorage("bodyShapeOverride") var bodyShapeRaw: String = "neutral"

    var bodyShape: BodyShape {
        switch bodyShapeRaw {
        case "masculine": return .masculine
        case "feminine": return .feminine
        default: return .neutral   // includes any legacy "auto" value
        }
    }
}
