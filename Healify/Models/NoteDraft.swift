import Foundation

/// A mutable, view-friendly draft of a journal note. Shared by single-note,
/// bulk-note, and bulk-wound-create flows so the note fields stay consistent.
struct NoteDraft {
    var timestamp: Date = .now
    var text: String = ""
    var recordPain: Bool = false
    var pain: Double = 3
    var symptoms: Set<Symptom> = []
    var isClinician: Bool = false
    var hasExpectedDays: Bool = false
    var expectedDays: Double = 14

    /// True when there's nothing worth saving.
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty && symptoms.isEmpty && !recordPain && !isClinician
    }

    /// Materializes a fresh `JournalNote` (unattached). Call once per wound for
    /// bulk flows so each wound gets its own note instance.
    func makeNote() -> JournalNote {
        JournalNote(
            timestamp: timestamp,
            text: text,
            painLevel: recordPain ? Int(pain) : nil,
            symptoms: Array(symptoms),
            isClinicianGuidance: isClinician,
            expectedHealingDays: (isClinician && hasExpectedDays) ? Int(expectedDays) : nil
        )
    }
}
