import SwiftUI

/// One wound in a list/drawer: thumbnail, name, location, counts, and (if AI is
/// enabled) the latest healing score.
struct WoundRow: View {
    @EnvironmentObject private var settings: AppSettings
    let wound: Wound

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let photo = wound.latestPhoto {
                    PhotoThumbnail(filename: photo.imageFilename, maxPixel: 200)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .overlay(Image(systemName: wound.kind.symbol).foregroundStyle(.secondary))
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(wound.name).font(.headline)
                if !wound.locationDescription.isEmpty {
                    Text(wound.locationDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\(wound.photos.count) photo\(wound.photos.count == 1 ? "" : "s") · \(wound.notes.count) note\(wound.notes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if settings.aiScoringEnabled, let score = wound.latestScore {
                ScoreRing(score: score, size: 42, lineWidth: 5, caption: nil)
            }
        }
        .padding(.vertical, 4)
    }
}
