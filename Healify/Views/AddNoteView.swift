import SwiftUI
import SwiftData

/// Structured note entry: free text, timestamp, optional 0–10 pain, symptom
/// flags, and optional clinician guidance with an expected healing duration.
struct AddNoteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let wound: Wound

    @State private var timestamp = Date.now
    @State private var text = ""
    @State private var recordPain = false
    @State private var pain = 3.0
    @State private var symptoms: Set<Symptom> = []
    @State private var isClinician = false
    @State private var hasExpectedDays = false
    @State private var expectedDays = 14.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("When", selection: $timestamp)
                    TextField("What did you observe?", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Pain") {
                    Toggle("Record pain level", isOn: $recordPain.animation())
                    if recordPain {
                        VStack {
                            HStack {
                                Text("0").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $pain, in: 0...10, step: 1)
                                Text("10").font(.caption).foregroundStyle(.secondary)
                            }
                            Text("Pain: \(Int(pain))/10")
                                .font(.headline)
                                .foregroundStyle(Int(pain).painColor)
                        }
                    }
                }

                Section("Symptoms") {
                    ForEach(Symptom.allCases) { symptom in
                        Button {
                            toggle(symptom)
                        } label: {
                            HStack {
                                Label(symptom.label, systemImage: symptom.symbol)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if symptoms.contains(symptom) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Clinician guidance", isOn: $isClinician.animation())
                    if isClinician {
                        Toggle("Expected time to heal", isOn: $hasExpectedDays.animation())
                        if hasExpectedDays {
                            Stepper(value: $expectedDays, in: 1...365, step: 1) {
                                Text("~\(Int(expectedDays)) days")
                            }
                        }
                    }
                } header: {
                    Text("Source")
                } footer: {
                    Text("Mark notes from your doctor as clinician guidance. An expected healing time helps anchor the timeline estimate.")
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty && symptoms.isEmpty && !recordPain)
                }
            }
        }
    }

    private func toggle(_ symptom: Symptom) {
        if symptoms.contains(symptom) { symptoms.remove(symptom) } else { symptoms.insert(symptom) }
    }

    private func save() {
        let note = JournalNote(
            timestamp: timestamp,
            text: text,
            painLevel: recordPain ? Int(pain) : nil,
            symptoms: Array(symptoms),
            isClinicianGuidance: isClinician,
            expectedHealingDays: (isClinician && hasExpectedDays) ? Int(expectedDays) : nil
        )
        note.wound = wound
        wound.notes.append(note)
        context.insert(note)
        dismiss()
    }
}

#Preview {
    AddNoteView(wound: Wound(name: "Test"))
        .modelContainer(PreviewData.container)
}
