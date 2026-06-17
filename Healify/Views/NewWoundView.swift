import SwiftUI
import SwiftData

struct NewWoundView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: Wound?
    var presetRegion: BodyRegion?
    var onCreate: ((Wound) -> Void)?

    @State private var name = ""
    @State private var detail = ""
    @State private var kind: WoundKind = .other
    @State private var targetScore: Double = 90
    @State private var region: BodyRegion?
    @State private var bodyView: BodyView = .front

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Knee scrape)", text: $name)
                        .accessibilityIdentifier("woundName")
                    TextField("Location detail (optional, e.g. 2cm below kneecap)", text: $detail)
                    Picker("Type", selection: $kind) {
                        ForEach(WoundKind.allCases) { k in
                            Label(k.label, systemImage: k.symbol).tag(k)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    BodyMapView(
                        bodyView: $bodyView,
                        selection: region,
                        onTapRegion: { region = $0 }
                    )
                    .frame(height: 360)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)

                    if let region {
                        LabeledContent("Location", value: region.displayName)
                    }
                } header: {
                    Text("Where is it?")
                } footer: {
                    Text(region == nil ? "Tap the body to mark the wound's location." : "Tap again to move it.")
                }

                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Healed target")
                            Spacer()
                            Text("\(Int(targetScore))").foregroundStyle(.secondary)
                        }
                        Slider(value: $targetScore, in: 60...100, step: 5)
                    }
                } header: {
                    Text("Goal")
                } footer: {
                    Text("The healing score this wound should reach before it's considered resolved.")
                }
            }
            .navigationTitle(isEditing ? "Edit Wound" : "New Wound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadInitial)
        }
    }

    private func loadInitial() {
        if let existing {
            name = existing.name
            detail = existing.bodyLocation
            kind = existing.kind
            targetScore = existing.targetScore
            region = existing.bodyRegion
            if let v = existing.bodyRegion?.view { bodyView = v }
        } else if let presetRegion {
            region = presetRegion
            bodyView = presetRegion.view
        }
    }

    private func save() {
        // Keep the front/back toggle in sync with the chosen region's view.
        if let region, region.view != bodyView {
            self.region = BodyRegion(part: region.part, side: region.side, view: bodyView)
        }
        if let existing {
            existing.name = name
            existing.bodyLocation = detail
            existing.kind = kind
            existing.targetScore = targetScore
            existing.bodyRegion = region
        } else {
            let wound = Wound(name: name, bodyLocation: detail, bodyRegion: region,
                              kind: kind, targetScore: targetScore)
            context.insert(wound)
            onCreate?(wound)
        }
        dismiss()
    }
}

#Preview {
    NewWoundView()
        .modelContainer(PreviewData.container)
        .environmentObject(AppSettings())
}
