import SwiftUI
import SwiftData

/// Create several wounds at once — tap each spot on the body map — sharing a
/// type and one initial note (e.g. all happened in the same fall). Each wound
/// gets its own copy of the note.
struct BulkAddWoundsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var health: HealthProfileService
    @EnvironmentObject private var settings: AppSettings

    @State private var regions: [BodyRegion] = []
    @State private var names: [String: String] = [:]
    @State private var kind: WoundKind = .other
    @State private var bodyView: BodyView = .front
    @State private var addInitialNote = false
    @State private var draft = NoteDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    BodyMapView(
                        shape: settings.resolvedBodyShape(auto: health.bodyShape),
                        bodyView: $bodyView,
                        selected: Set(regions),
                        onTapRegion: toggle
                    )
                    .frame(height: 340)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                } header: {
                    Text("Tap each spot")
                } footer: {
                    Text(regions.isEmpty ? "Tap the body to mark each wound." : "\(regions.count) selected. Tap a spot again to remove it.")
                }

                if !regions.isEmpty {
                    Section("Name each") {
                        ForEach(regions) { region in
                            HStack {
                                Image(systemName: "circle.fill").font(.caption2).foregroundStyle(Color.accentColor)
                                TextField(region.displayName, text: nameBinding(region))
                            }
                        }
                    }

                    Section("Type (all)") {
                        Picker("Type", selection: $kind) {
                            ForEach(WoundKind.allCases) { k in
                                Label(k.label, systemImage: k.symbol).tag(k)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    Section {
                        Toggle("Add an initial note to all", isOn: $addInitialNote.animation())
                    } footer: {
                        Text("Handy when they happened at the same time — the same note is logged on every wound.")
                    }

                    if addInitialNote {
                        NoteEditor(draft: $draft, textPrompt: "What happened? (applied to all)")
                    }
                }
            }
            .navigationTitle("Several Wounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create \(regions.count)", action: save).disabled(regions.isEmpty)
                }
            }
            .task { await health.load() }
        }
    }

    private func toggle(_ region: BodyRegion) {
        if let idx = regions.firstIndex(of: region) { regions.remove(at: idx) }
        else { regions.append(region) }
    }

    private func nameBinding(_ region: BodyRegion) -> Binding<String> {
        Binding(get: { names[region.id] ?? "" }, set: { names[region.id] = $0 })
    }

    private func save() {
        for region in regions {
            let custom = names[region.id]?.trimmingCharacters(in: .whitespaces)
            let name = (custom?.isEmpty == false) ? custom! : region.displayName
            let wound = Wound(name: name, bodyRegion: region, kind: kind)
            context.insert(wound)
            if addInitialNote && !draft.isEmpty {
                let note = draft.makeNote()
                note.wound = wound
                wound.notes.append(note)
                context.insert(note)
            }
        }
        dismiss()
    }
}

#Preview {
    BulkAddWoundsView()
        .modelContainer(PreviewData.container)
        .environmentObject(HealthProfileService())
        .environmentObject(AppSettings())
}
