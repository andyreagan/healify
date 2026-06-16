import Foundation
import SwiftData

/// Drives on-device analysis for a wound: extracts any missing photo features
/// off the main thread, then computes and persists healing scores.
///
/// Heavy Core Image / Vision work runs in a detached task on the raw image
/// bytes; only the cheap model writes happen back on the main actor where the
/// SwiftData context lives.
@MainActor
final class HealingService: ObservableObject {
    @Published private(set) var isAnalyzing = false
    @Published private(set) var progress: Double = 0

    func analyze(_ wound: Wound, in context: ModelContext) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        progress = 0
        defer { isAnalyzing = false }

        let photos = wound.photosByDate
        guard !photos.isEmpty else { return }

        // 1. Compute features for photos that lack them (or are stale).
        let stale = photos.filter {
            $0.rednessIndex == nil || $0.analysisVersion != HealingAnalyzer.version
        }
        for (index, photo) in stale.enumerated() {
            let filename = photo.imageFilename
            // Read + analyze off the main thread.
            let features: PhotoFeatures? = await Task.detached(priority: .userInitiated) {
                guard let data = ImageStore.loadData(filename) else { return nil }
                return HealingAnalyzer.features(for: data)
            }.value

            if let features {
                photo.rednessIndex = features.rednessIndex
                photo.featurePrint = features.featurePrint
                photo.analysisVersion = HealingAnalyzer.version
            }
            progress = Double(index + 1) / Double(stale.count) * 0.8
        }

        // 2. Score the whole series relative to the baseline.
        let samples = photos.map {
            HealingScoring.Sample(id: $0.id, redness: $0.rednessIndex ?? 0, featurePrint: $0.featurePrint)
        }
        let scores = HealingScoring.scores(for: samples)
        for photo in photos {
            photo.healingScore = scores[photo.id]
        }
        progress = 1

        try? context.save()
    }
}
