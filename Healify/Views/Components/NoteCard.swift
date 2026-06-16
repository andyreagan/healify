import SwiftUI

/// A single journal note rendered as a card: clinician tag, timestamp, text,
/// pain, expected-days, and symptom chips.
struct NoteCard: View {
    let note: JournalNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Note", systemImage: "square.and.pencil")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if note.isClinicianGuidance {
                    Label("Clinician", systemImage: "stethoscope")
                        .font(.caption.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Text(Format.dayTime(note.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !note.text.isEmpty {
                Text(note.text).font(.body)
            }

            HStack(spacing: 8) {
                if let pain = note.painLevel {
                    Label("Pain \(pain)/10", systemImage: "bolt.heart")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(pain.painColor.opacity(0.2), in: Capsule())
                        .foregroundStyle(pain.painColor)
                }
                if let days = note.expectedHealingDays, note.isClinicianGuidance {
                    Label("~\(days) days to heal", systemImage: "calendar")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(.systemGray5), in: Capsule())
                }
            }

            if !note.symptoms.isEmpty {
                SymptomChips(symptoms: note.symptoms)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Wrapping row of symptom chips; infection-flag symptoms are tinted red.
struct SymptomChips: View {
    let symptoms: [Symptom]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            chips
            ScrollView(.horizontal, showsIndicators: false) { chips }
        }
    }
    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(symptoms) { s in
                Label(s.label, systemImage: s.symbol)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(s.isInfectionFlag ? Color.red.opacity(0.15) : Color(.systemGray6), in: Capsule())
                    .foregroundStyle(s.isInfectionFlag ? .red : .primary)
            }
        }
    }
}
