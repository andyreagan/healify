import Testing
import Foundation
import SwiftData
@testable import Healify

@MainActor
@Suite struct HealingTimelineTests {
    /// Builds a wound with photos carrying the given (dayOffset, score) points.
    private func wound(_ context: ModelContext, points: [(Int, Double)] = [], target: Double = 90) -> Wound {
        let w = Wound(name: "W", targetScore: target)
        context.insert(w)
        for (offset, score) in points {
            let p = WoundPhoto(imageFilename: "x.jpg", captureDate: TestSupport.day(offset))
            p.healingScore = score
            p.wound = w
            w.photos.append(p)
            context.insert(p)
        }
        return w
    }

    @Test func noPhotosNoNotesGivesNoProjection() throws {
        let ctx = try TestSupport.makeContext()
        #expect(HealingTimeline.project(for: wound(ctx)) == nil)
    }

    @Test func improvingTrendProjectsFutureDate() throws {
        let ctx = try TestSupport.makeContext()
        let w = wound(ctx, points: [(0, 10), (10, 30), (20, 50)], target: 90)
        let projection = try #require(HealingTimeline.project(for: w))
        #expect(projection.basis == .trend)
        // Last point is day 20 score 50; slope 2/day → ~20 more days to 90.
        #expect(projection.estimatedDate > TestSupport.day(20))
        #expect((projection.ratePerDay ?? 0) > 1.5)
    }

    @Test func flatTrendHasNoProjection() throws {
        let ctx = try TestSupport.makeContext()
        let w = wound(ctx, points: [(0, 40), (10, 40), (20, 40)])
        #expect(HealingTimeline.project(for: w) == nil)
    }

    @Test func clinicianOnlyUsesExpectedDays() throws {
        let ctx = try TestSupport.makeContext()
        let w = wound(ctx) // no scored photos
        let note = JournalNote(timestamp: TestSupport.day(0), text: "doc",
                               isClinicianGuidance: true, expectedHealingDays: 14)
        note.wound = w
        w.notes.append(note)
        ctx.insert(note)

        let projection = try #require(HealingTimeline.project(for: w))
        #expect(projection.basis == .clinician)
        let expected = TestSupport.day(14)
        #expect(abs(projection.estimatedDate.timeIntervalSince(expected)) < 1)
    }

    @Test func trendPlusClinicianBlends() throws {
        let ctx = try TestSupport.makeContext()
        let w = wound(ctx, points: [(0, 10), (10, 30)])
        let note = JournalNote(timestamp: TestSupport.day(0), text: "doc",
                               isClinicianGuidance: true, expectedHealingDays: 21)
        note.wound = w
        w.notes.append(note)
        ctx.insert(note)

        let projection = try #require(HealingTimeline.project(for: w))
        #expect(projection.basis == .blended)
    }
}
