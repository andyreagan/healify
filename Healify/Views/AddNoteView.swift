import SwiftUI
import SwiftData

struct AddNoteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let wound: Wound
    var existing: JournalNote?

    @State private var draft = NoteDraft()
    @State private var showingDeleteConfirm = false
    @State private var loaded = false

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                NoteEditor(draft: $draft)

                if isEditing {
                    Section {
                        Button(role: .destructive) { showingDeleteConfirm = true } label: {
                            Label("Delete Note", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(draft.isEmpty)
                }
            }
            .confirmationDialog("Delete this note?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            }
            .onAppear {
                // Seed once from the existing note when editing.
                if !loaded {
                    if let existing { draft = NoteDraft(from: existing) }
                    loaded = true
                }
            }
        }
    }

    private func save() {
        if let existing {
            draft.apply(to: existing)
        } else {
            let note = draft.makeNote()
            note.wound = wound
            wound.notes.append(note)
            context.insert(note)
        }
        dismiss()
    }

    private func delete() {
        if let existing {
            // Remove from the relationship so the timeline updates immediately.
            wound.notes.removeAll { $0 == existing }
            context.delete(existing)
            try? context.save()
        }
        dismiss()
    }
}

#Preview {
    AddNoteView(wound: Wound(name: "Test"))
        .modelContainer(PreviewData.container)
}
