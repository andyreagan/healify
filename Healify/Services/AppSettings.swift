import SwiftUI

/// User preferences. AI scoring is opt-in and off by default.
final class AppSettings: ObservableObject {
    @AppStorage("aiScoringEnabled") var aiScoringEnabled: Bool = false
    @AppStorage("autoAnalyzeOnAdd") var autoAnalyzeOnAdd: Bool = true
    @AppStorage("aiDisclaimerAcknowledged") var aiDisclaimerAcknowledged: Bool = false
    @AppStorage("bodyShapeOverride") var bodyShapeRaw: String = "neutral"

    var bodyShape: BodyShape {
        switch bodyShapeRaw {
        case "masculine": return .masculine
        case "feminine": return .feminine
        default: return .neutral   // includes any legacy "auto" value
        }
    }
}
