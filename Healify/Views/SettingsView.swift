import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @State private var showingDisclaimer = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showingImporter = false
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("On-device healing analysis", isOn: aiBinding)
                    if settings.aiScoringEnabled {
                        Toggle("Auto-analyze when adding photos", isOn: $settings.autoAnalyzeOnAdd)
                    }
                } header: {
                    Text("AI")
                } footer: {
                    Text("All analysis runs on your device using Apple's Vision and Core Image. Photos never leave your phone and nothing is sent to a server.")
                }

                Section {
                    Picker("Body type", selection: $settings.bodyShapeRaw) {
                        Text("Neutral").tag("neutral")
                        Text("Masculine").tag("masculine")
                        Text("Feminine").tag("feminine")
                    }
                } header: {
                    Text("Body map")
                } footer: {
                    Text("Sets how the body map silhouette looks when marking wound locations.")
                }

                Section {
                    Button(action: exportBackup) {
                        Label("Export backup…", systemImage: "square.and.arrow.up")
                    }
                    Button { showingImporter = true } label: {
                        Label("Import backup…", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Export saves all wounds, notes, and photos to a single backup file you can keep in Files or iCloud — do this before updating the app, or to move to a new phone. Import merges a backup back in (existing entries are skipped).")
                }

                Section("Privacy") {
                    LabeledContent("Photo storage", value: "On device")
                    LabeledContent("Cloud sync", value: "None")
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                } footer: {
                    Text("Healify is a personal wound-tracking journal. It does not provide medical advice. For any concern about a wound, contact a healthcare professional.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingDisclaimer) {
                AIDisclaimerView {
                    settings.aiDisclaimerAcknowledged = true
                    settings.aiScoringEnabled = true
                }
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(items: [url])
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .alert("Export failed", isPresented: .init(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(exportError ?? "") }
            .alert("Backup", isPresented: .init(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(resultMessage ?? "") }
        }
    }

    /// Enabling AI for the first time routes through the disclaimer.
    private var aiBinding: Binding<Bool> {
        Binding(
            get: { settings.aiScoringEnabled },
            set: { newValue in
                if newValue && !settings.aiDisclaimerAcknowledged {
                    showingDisclaimer = true
                } else {
                    settings.aiScoringEnabled = newValue
                }
            }
        )
    }

    private func exportBackup() {
        do {
            exportURL = try DataExport.makeBackup(context)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let s = try DataImport.restore(from: url, into: context)
                resultMessage = "Imported \(s.woundsAdded) wound\(s.woundsAdded == 1 ? "" : "s") "
                    + "(\(s.photosAdded) photos, \(s.notesAdded) notes)."
                    + (s.woundsSkipped > 0 ? " Skipped \(s.woundsSkipped) already present." : "")
            } catch {
                resultMessage = error.localizedDescription
            }
        case .failure(let error):
            resultMessage = error.localizedDescription
        }
    }
}

struct AIDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    var onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                    Text("Before you turn this on")
                        .font(.title2.bold())
                    bullet("Runs entirely on your device", "Vision and Core Image analyze photos locally. Nothing is uploaded.")
                    bullet("It's an estimate, not a diagnosis", "Scores reflect visible inflammation and change between photos — not a medical assessment.")
                    bullet("See a professional when unsure", "Signs of infection (spreading redness, warmth, pus, fever) need real medical care.")
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button { onAccept(); dismiss() } label: {
                        Text("I Understand — Enable").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Not Now") { dismiss() }
                }
                .padding()
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func bullet(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .modelContainer(PreviewData.container)
}
