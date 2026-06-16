import SwiftUI
import SwiftData

/// Add a single structured note to one wound. Uses the shared `NoteEditor`.
struct AddNoteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let wound: Wound

    @State private var draft = NoteDraft()

    var body: some View {
        NavigationStack {
            Form {
                NoteEditor(draft: $draft)
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.isEmpty)
                }
            }
        }
    }

    private func save() {
        let note = draft.makeNote()
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
