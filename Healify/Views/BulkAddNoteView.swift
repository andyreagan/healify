import SwiftUI
import SwiftData

/// Logs the same note against several wounds at once — e.g. "changed all
/// dressings". Each selected wound gets its own copy of the note.
struct BulkAddNoteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wound.createdAt, order: .reverse) private var wounds: [Wound]

    @State private var selected: Set<UUID> = []
    @State private var draft = NoteDraft()

    private var active: [Wound] { wounds.filter { !$0.isArchived } }
    private var canSave: Bool { !selected.isEmpty && !draft.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if active.isEmpty {
                        Text("No active wounds to add a note to.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(active) { wound in
                            Button {
                                toggle(wound.id)
                            } label: {
                                HStack {
                                    Image(systemName: selected.contains(wound.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(wound.id) ? Color.accentColor : .secondary)
                                    VStack(alignment: .leading) {
                                        Text(wound.name).foregroundStyle(.primary)
                                        if !wound.locationDescription.isEmpty {
                                            Text(wound.locationDescription).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Apply to")
                        Spacer()
                        if !active.isEmpty {
                            Button(selected.count == active.count ? "Clear" : "Select all") {
                                selected = selected.count == active.count ? [] : Set(active.map(\.id))
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                } footer: {
                    Text("\(selected.count) of \(active.count) selected.")
                }

                NoteEditor(draft: $draft)
            }
            .navigationTitle("Note for Several")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func save() {
        for wound in active where selected.contains(wound.id) {
            let note = draft.makeNote() // fresh instance per wound
            note.wound = wound
            wound.notes.append(note)
            context.insert(note)
        }
        dismiss()
    }
}

#Preview {
    BulkAddNoteView()
        .modelContainer(PreviewData.container)
}
