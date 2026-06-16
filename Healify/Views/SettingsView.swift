import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @State private var showingDisclaimer = false

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
}

/// One-time disclaimer shown before enabling AI scoring.
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
                    Button {
                        onAccept(); dismiss()
                    } label: {
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
    SettingsView().environmentObject(AppSettings())
}
