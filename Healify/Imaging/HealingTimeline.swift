import Foundation

/// A projected healing estimate for a wound.
struct HealingProjection {
    enum Basis {
        case trend          // purely from the photo-score trajectory
        case clinician      // purely from a doctor's expected-days note
        case blended        // both signals combined
    }

    let estimatedDate: Date
    let basis: Basis
    /// 0–1 confidence, mostly a function of how many data points exist.
    let confidence: Double
    /// Score-per-day improvement (nil when clinician-only).
    let ratePerDay: Double?

    var basisDescription: String {
        switch basis {
        case .trend: return "Based on your photo trend"
        case .clinician: return "Based on your clinician's estimate"
        case .blended: return "Photo trend + clinician estimate"
        }
    }
}

/// Projects when a wound is likely to reach its target score, blending the
/// observed photo-score trajectory with any clinician-provided estimate.
enum HealingTimeline {
    static func project(for wound: Wound) -> HealingProjection? {
        let trend = projectFromTrend(for: wound)
        let clinician = projectFromClinician(for: wound)

        switch (trend, clinician) {
        case let (t?, c?):
            // Trend weight grows with confidence; the clinician estimate anchors
            // the early, data-poor phase.
            let tWeight = t.confidence
            let cWeight = 0.6
            let blended = Date(
                timeIntervalSince1970:
                    (t.estimatedDate.timeIntervalSince1970 * tWeight
                     + c.estimatedDate.timeIntervalSince1970 * cWeight) / (tWeight + cWeight)
            )
            return HealingProjection(
                estimatedDate: blended,
                basis: .blended,
                confidence: min(1, t.confidence + 0.2),
                ratePerDay: t.ratePerDay
            )
        case let (t?, nil): return t
        case let (nil, c?): return c
        default: return nil
        }
    }

    /// Linear fit of score vs. days, extrapolated to the target score.
    private static func projectFromTrend(for wound: Wound) -> HealingProjection? {
        let scored = wound.photosByDate.compactMap { photo -> (day: Double, score: Double, date: Date)? in
            guard let score = photo.healingScore else { return nil }
            return (photo.captureDate.timeIntervalSince1970 / 86_400, score, photo.captureDate)
        }
        guard scored.count >= 2,
              let last = scored.last,
              let baselineDay = scored.first?.day else { return nil }

        // Ordinary least squares slope (score units per day).
        let n = Double(scored.count)
        let meanX = scored.map(\.day).reduce(0, +) / n
        let meanY = scored.map(\.score).reduce(0, +) / n
        let num = scored.reduce(0) { $0 + ($1.day - meanX) * ($1.score - meanY) }
        let den = scored.reduce(0) { $0 + pow($1.day - meanX, 2) }
        guard den > 0 else { return nil }
        let slope = num / den
        guard slope > 0.05 else { return nil } // stalled or worsening → no estimate

        let remaining = wound.targetScore - last.score
        guard remaining > 0 else { // already at/over target
            return HealingProjection(estimatedDate: last.date, basis: .trend, confidence: 0.9, ratePerDay: slope)
        }
        let estimated = last.date.addingTimeInterval(remaining / slope * 86_400)

        // Confidence grows with sample count and observed span.
        let spanDays = last.day - baselineDay
        let confidence = min(0.85, 0.3 + 0.1 * (n - 2) + min(0.25, spanDays / 60))
        return HealingProjection(estimatedDate: estimated, basis: .trend, confidence: confidence, ratePerDay: slope)
    }

    /// Most recent clinician-guidance note with expected days, anchored at its date.
    private static func projectFromClinician(for wound: Wound) -> HealingProjection? {
        let guidance = wound.notes
            .filter { $0.isClinicianGuidance && ($0.expectedHealingDays ?? 0) > 0 }
            .max { $0.timestamp < $1.timestamp }
        guard let guidance, let days = guidance.expectedHealingDays else { return nil }
        let estimated = guidance.timestamp.addingTimeInterval(Double(days) * 86_400)
        return HealingProjection(estimatedDate: estimated, basis: .clinician, confidence: 0.5, ratePerDay: nil)
    }
}
