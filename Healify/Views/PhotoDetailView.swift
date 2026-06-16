import SwiftUI
import SwiftData

/// Full-size photo with editable capture timestamp, caption, analysis readout,
/// and delete. Adjusting the timestamp is what keeps the timeline accurate when
/// EXIF is missing or wrong.
struct PhotoDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @Bindable var photo: WoundPhoto
    let wound: Wound

    @State private var fullImage: UIImage?
    @State private var showingDeleteConfirm = false
    @State private var editorImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imageView

                // Capture date — adjustable.
                VStack(alignment: .leading, spacing: 8) {
                    Label("Capture date & time", systemImage: "clock")
                        .font(.headline)
                    DatePicker("Captured", selection: $photo.captureDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .onChange(of: photo.captureDate) { _, _ in
                            photo.captureDateAdjusted = (photo.exifCaptureDate != photo.captureDate)
                        }
                    HStack(spacing: 12) {
                        if let exif = photo.exifCaptureDate {
                            Text(photo.captureDateAdjusted ? "Adjusted from photo's \(Format.dayTime(exif))" : "From photo metadata")
                                .font(.caption).foregroundStyle(.secondary)
                            if photo.captureDateAdjusted {
                                Button("Reset") {
                                    photo.captureDate = exif
                                    photo.captureDateAdjusted = false
                                }
                                .font(.caption)
                            }
                        } else {
                            Text("No metadata in this photo — set the time it was taken.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                // Caption
                VStack(alignment: .leading, spacing: 8) {
                    Label("Caption", systemImage: "text.alignleft").font(.headline)
                    TextField("Add a caption…", text: $photo.caption, axis: .vertical)
                        .lineLimit(1...4)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                if settings.aiScoringEnabled {
                    analysisSection
                }
            }
            .padding()
        }
        .navigationTitle(Format.day(photo.captureDate))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Load full resolution for editing (not the display thumbnail).
                    editorImage = ImageStore.loadImage(photo.imageFilename)
                } label: {
                    Image(systemName: "crop.rotate")
                }
                .disabled(fullImage == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this photo?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Photo", role: .destructive, action: deletePhoto)
        }
        .fullScreenCover(isPresented: Binding(get: { editorImage != nil }, set: { if !$0 { editorImage = nil } })) {
            if let editorImage {
                PhotoEditorView(image: editorImage) { edited in applyEdit(edited) }
            }
        }
        .task(id: photo.imageFilename) {
            let name = photo.imageFilename
            fullImage = await Task.detached { ImageStore.thumbnail(name, maxPixel: 1600) }.value
        }
    }

    /// Saves the edited image as a new file, repoints the photo, and invalidates
    /// the cached AI analysis since the pixels changed.
    private func applyEdit(_ edited: UIImage) {
        guard let newName = try? ImageStore.saveImage(edited) else { return }
        let old = photo.imageFilename
        photo.imageFilename = newName
        photo.healingScore = nil
        photo.rednessIndex = nil
        photo.featurePrint = nil
        photo.analysisVersion = nil
        try? context.save()
        ImageStore.delete(old)
        fullImage = ImageStore.thumbnail(newName, maxPixel: 1600)
    }

    @ViewBuilder
    private var imageView: some View {
        if let fullImage {
            Image(uiImage: fullImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
                .frame(height: 280)
                .overlay(ProgressView())
        }
    }

    @ViewBuilder
    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("On-device analysis", systemImage: "wand.and.stars").font(.headline)
            if let score = photo.healingScore {
                HStack(spacing: 16) {
                    ScoreRing(score: score, size: 72, lineWidth: 8)
                    VStack(alignment: .leading, spacing: 6) {
                        if photo == wound.baselinePhoto {
                            Text("Baseline photo — this is what later photos are compared against.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Text("\(Int(score)) / 100 toward healed")
                                .font(.subheadline)
                        }
                        if let redness = photo.rednessIndex {
                            Text("Inflammation index: \(Int(redness * 100))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            } else {
                Text("Not analyzed yet — open the Overview tab and run analysis.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func deletePhoto() {
        ImageStore.delete(photo.imageFilename)
        context.delete(photo)
        try? context.save()
        dismiss()
    }
}
