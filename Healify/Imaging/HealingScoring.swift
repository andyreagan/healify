import Foundation

/// Turns a wound series' per-photo features into 0–100 healing scores relative
/// to the baseline (first photo), blending three signals: inflammation reduction
/// vs. baseline, visual divergence from baseline, and frame-to-frame settling.
/// A wellness heuristic, not a medical assessment.
enum HealingScoring {
    // Tunable references for normalizing raw signals into 0–1.
    private static let skinRedReference = 0.36      // typical red-share of healthy skin
    private static let closureReference: Float = 1.2 // Vision distance treated as "fully changed"
    private static let stabilizeReference: Float = 0.8

    private static let wRedness = 0.6
    private static let wClosure = 0.25
    private static let wStability = 0.15

    /// A snapshot of one photo's cached analysis.
    struct Sample {
        let id: UUID
        let redness: Double
        let featurePrint: Data?
    }

    /// Returns a score per sample id. Samples must be in chronological order.
    static func scores(for samples: [Sample]) -> [UUID: Double] {
        guard let baseline = samples.first else { return [:] }
        let r0 = baseline.redness
        // Target redness we'd expect once calmed: a fraction below baseline,
        // floored at healthy-skin reference so already-pale wounds behave.
        let rTarget = max(skinRedReference, r0 * 0.72)

        var result: [UUID: Double] = [:]
        for (index, sample) in samples.enumerated() {
            if index == 0 {
                result[sample.id] = 0 // baseline = day zero
                continue
            }

            // Inflammation reduction vs. baseline.
            let rednessProgress = r0 - rTarget > 0.0001
                ? clamp((r0 - sample.redness) / (r0 - rTarget), 0, 1)
                : 0.5

            // Divergence from baseline appearance.
            var closureProgress = 0.0
            if let d = HealingAnalyzer.distance(baseline.featurePrint, sample.featurePrint) {
                closureProgress = Double(clamp(d / closureReference, 0, 1))
            }

            // Settling relative to the previous photo.
            var stability = 0.0
            if let prevPrint = samples[index - 1].featurePrint,
               let d = HealingAnalyzer.distance(prevPrint, sample.featurePrint) {
                stability = Double(clamp(1 - d / stabilizeReference, 0, 1))
            }

            let composite = wRedness * rednessProgress
                + wClosure * closureProgress
                + wStability * stability
            result[sample.id] = (composite * 100).rounded()
        }
        return result
    }

    private static func clamp<T: Comparable>(_ value: T, _ low: T, _ high: T) -> T {
        min(max(value, low), high)
    }
}
