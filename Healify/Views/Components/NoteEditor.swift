import SwiftUI

/// Reusable `Form` sections for editing a `NoteDraft`. Embed inside a `Form`.
struct NoteEditor: View {
    @Binding var draft: NoteDraft
    /// Hide the date picker when the note's time is implied elsewhere.
    var showsDate: Bool = true
    var textPrompt: String = "What did you observe?"

    var body: some View {
        Group {
            Section {
                if showsDate {
                    DatePicker("When", selection: $draft.timestamp)
                }
                TextField(textPrompt, text: $draft.text, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityIdentifier("noteText")
            }

            Section("Pain") {
                Toggle("Record pain level", isOn: $draft.recordPain.animation())
                if draft.recordPain {
                    VStack {
                        HStack {
                            Text("0").font(.caption).foregroundStyle(.secondary)
                            Slider(value: $draft.pain, in: 0...10, step: 1)
                            Text("10").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Pain: \(Int(draft.pain))/10")
                            .font(.headline)
                            .foregroundStyle(Int(draft.pain).painColor)
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
                            if draft.symptoms.contains(symptom) {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Clinician guidance", isOn: $draft.isClinician.animation())
                if draft.isClinician {
                    Toggle("Expected time to heal", isOn: $draft.hasExpectedDays.animation())
                    if draft.hasExpectedDays {
                        Stepper(value: $draft.expectedDays, in: 1...365, step: 1) {
                            Text("~\(Int(draft.expectedDays)) days")
                        }
                    }
                }
            } header: {
                Text("Source")
            } footer: {
                Text("Mark notes from your doctor as clinician guidance. An expected healing time helps anchor the timeline estimate.")
            }
        }
    }

    private func toggle(_ symptom: Symptom) {
        if draft.symptoms.contains(symptom) { draft.symptoms.remove(symptom) }
        else { draft.symptoms.insert(symptom) }
    }
}
