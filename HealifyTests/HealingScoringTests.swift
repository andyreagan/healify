import Testing
import Foundation
@testable import Healify

@Suite struct HealingScoringTests {
    private func sample(_ redness: Double) -> HealingScoring.Sample {
        HealingScoring.Sample(id: UUID(), redness: redness, featurePrint: nil)
    }

    @Test func emptyInputGivesEmptyOutput() {
        #expect(HealingScoring.scores(for: []).isEmpty)
    }

    @Test func baselineScoresZero() {
        let samples = [sample(0.5), sample(0.4)]
        let scores = HealingScoring.scores(for: samples)
        #expect(scores[samples[0].id] == 0)
    }

    @Test func decliningRednessRaisesScore() {
        // Same baseline, progressively calmer.
        let samples = [sample(0.5), sample(0.45), sample(0.40), sample(0.36)]
        let scores = HealingScoring.scores(for: samples)
        let series = samples.map { scores[$0.id] ?? -1 }
        // Monotonic non-decreasing as redness falls toward the skin reference.
        for i in 1..<series.count {
            #expect(series[i] >= series[i - 1])
        }
        #expect((scores[samples.last!.id] ?? 0) > 0)
    }

    @Test func flareUpDoesNotReward() {
        // Redness increases vs. baseline → no progress credit.
        let samples = [sample(0.5), sample(0.65)]
        let scores = HealingScoring.scores(for: samples)
        #expect(scores[samples[1].id] == 0)
    }

    @Test func scoresStayInRange() {
        let samples = [sample(0.6), sample(0.5), sample(0.36), sample(0.2)]
        for value in HealingScoring.scores(for: samples).values {
            #expect(value >= 0 && value <= 100)
        }
    }
}
