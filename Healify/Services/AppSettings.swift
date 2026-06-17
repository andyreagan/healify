import SwiftUI

/// User preferences. AI scoring is opt-in and off by default.
final class AppSettings: ObservableObject {
    @AppStorage("aiScoringEnabled") var aiScoringEnabled: Bool = false
    @AppStorage("autoAnalyzeOnAdd") var autoAnalyzeOnAdd: Bool = true
    @AppStorage("aiDisclaimerAcknowledged") var aiDisclaimerAcknowledged: Bool = false
}
