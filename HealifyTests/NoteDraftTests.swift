import Testing
import Foundation
@testable import Healify

@Suite struct NoteDraftTests {
    @Test func emptyByDefault() {
        #expect(NoteDraft().isEmpty)
    }

    @Test func textMakesItNonEmpty() {
        var d = NoteDraft(); d.text = "looks better"
        #expect(!d.isEmpty)
    }

    @Test func painOnlyRecordedWhenToggled() {
        var d = NoteDraft(); d.pain = 7
        #expect(d.makeNote().painLevel == nil)
        d.recordPain = true
        #expect(d.makeNote().painLevel == 7)
    }

    @Test func expectedDaysNeedsClinicianAndToggle() {
        var d = NoteDraft()
        d.hasExpectedDays = true
        d.expectedDays = 14
        // Not clinician yet → ignored.
        #expect(d.makeNote().expectedHealingDays == nil)
        d.isClinician = true
        #expect(d.makeNote().expectedHealingDays == 14)
    }

    @Test func symptomsArePassedThrough() {
        var d = NoteDraft(); d.symptoms = [.redness, .swelling]
        let note = d.makeNote()
        #expect(Set(note.symptoms) == [.redness, .swelling])
    }
}
