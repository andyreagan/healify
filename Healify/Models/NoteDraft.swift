import Foundation

/// A mutable, view-friendly draft of a journal note, shared across the note and
/// wound-create flows.
struct NoteDraft {
    var timestamp: Date = .now
    var text: String = ""
    var recordPain: Bool = false
    var pain: Double = 3
    var symptoms: Set<Symptom> = []
    var isClinician: Bool = false
    var hasExpectedDays: Bool = false
    var expectedDays: Double = 14

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty && symptoms.isEmpty && !recordPain && !isClinician
    }

    /// A fresh unattached `JournalNote`. Call once per wound in bulk flows.
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

    func apply(to note: JournalNote) {
        note.timestamp = timestamp
        note.text = text
        note.painLevel = recordPain ? Int(pain) : nil
        note.symptoms = Array(symptoms)
        note.isClinicianGuidance = isClinician
        note.expectedHealingDays = (isClinician && hasExpectedDays) ? Int(expectedDays) : nil
    }
}

extension NoteDraft {
    /// Seeds a draft from an existing note. In an extension so the synthesized
    /// memberwise initializer is preserved.
    init(from note: JournalNote) {
        self.init()
        timestamp = note.timestamp
        text = note.text
        recordPain = note.painLevel != nil
        pain = Double(note.painLevel ?? 3)
        symptoms = Set(note.symptoms)
        isClinician = note.isClinicianGuidance
        hasExpectedDays = note.expectedHealingDays != nil
        expectedDays = Double(note.expectedHealingDays ?? 14)
    }
}
