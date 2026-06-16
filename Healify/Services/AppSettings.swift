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

    /// Body-map silhouette: "auto" follows Apple Health (when available),
    /// otherwise an explicit choice. Lets the body map work without HealthKit.
    @AppStorage("bodyShapeOverride") var bodyShapeOverride: String = "auto"

    /// Resolves the silhouette to draw, given the auto-detected Health value.
    func resolvedBodyShape(auto: BodyShape) -> BodyShape {
        switch bodyShapeOverride {
        case "masculine": return .masculine
        case "feminine": return .feminine
        case "neutral": return .neutral
        default: return auto
        }
    }
}
