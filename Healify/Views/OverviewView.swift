import SwiftUI
import SwiftData
import Charts

/// The opt-in AI overview: on-device healing score, baseline-vs-latest compare,
/// score trend, and a timeline projection blended with clinician guidance.
struct OverviewView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var healingService: HealingService

    let wound: Wound

    @State private var showingDisclaimer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !settings.aiScoringEnabled {
                    optInCard
                } else if wound.photos.isEmpty {
                    ContentUnavailableView("Add a photo to begin",
                        systemImage: "wand.and.stars",
                        description: Text("Healing analysis needs at least one photo. The first one becomes your baseline."))
                        .padding(.top, 40)
                } else {
                    scoreHeader
                    analyzeControls
                    if let projection = HealingTimeline.project(for: wound) {
                        timelineCard(projection)
                    }
                    if scoredPhotos.count >= 2 {
                        trendChart
                    }
                    comparisonCard
                    disclaimerFooter
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingDisclaimer) {
            AIDisclaimerView {
                settings.aiDisclaimerAcknowledged = true
                settings.aiScoringEnabled = true
                Task { await healingService.analyze(wound, in: context) }
            }
        }
    }

    private var scoredPhotos: [WoundPhoto] {
        wound.photosByDate.filter { $0.healingScore != nil }
    }

    // MARK: Opt-in

    private var optInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("On-device healing analysis")
                .font(.title3.bold())
            Text("Healify can estimate healing progress by comparing each photo to your baseline — measuring inflammation and visual change. It runs entirely on your device; no photos ever leave your phone.")
                .foregroundStyle(.secondary)
            Text("This is a wellness aid, not medical advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                if settings.aiDisclaimerAcknowledged {
                    settings.aiScoringEnabled = true
                    Task { await healingService.analyze(wound, in: context) }
                } else {
                    showingDisclaimer = true
                }
            } label: {
                Text("Turn On Analysis").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Score

    private var scoreHeader: some View {
        HStack(spacing: 20) {
            ScoreRing(score: wound.latestScore ?? 0)
            VStack(alignment: .leading, spacing: 6) {
                Text(headline).font(.headline)
                Text(subhead).font(.subheadline).foregroundStyle(.secondary)
                if let warning = infectionWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var headline: String {
        guard let score = wound.latestScore else { return "Not analyzed yet" }
        switch score {
        case ..<25: return "Early stage"
        case ..<50: return "Healing underway"
        case ..<75: return "Healing well"
        case ..<Double(wound.targetScore): return "Nearly there"
        default: return "Looks healed"
        }
    }

    private var subhead: String {
        let n = scoredPhotos.count
        guard n > 0 else { return "Run analysis to compute a score." }
        return "From \(n) analyzed photo\(n == 1 ? "" : "s") over \(spanDescription)."
    }

    private var spanDescription: String {
        guard let first = scoredPhotos.first?.captureDate,
              let last = scoredPhotos.last?.captureDate else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return "\(max(0, days)) day\(days == 1 ? "" : "s")"
    }

    /// Surfaces an infection caution if recent notes flag warning symptoms.
    private var infectionWarning: String? {
        let recent = wound.notes.filter { $0.timestamp > Date.now.addingTimeInterval(-3 * 86_400) }
        let flags = Set(recent.flatMap(\.symptoms)).filter(\.isInfectionFlag)
        guard !flags.isEmpty else { return nil }
        return "Possible infection signs noted — consider contacting a clinician."
    }

    // MARK: Analyze controls

    private var analyzeControls: some View {
        VStack(spacing: 8) {
            if healingService.isAnalyzing {
                ProgressView(value: healingService.progress) {
                    Text("Analyzing on device…").font(.caption)
                }
            } else {
                Button {
                    Task { await healingService.analyze(wound, in: context) }
                } label: {
                    Label(scoredPhotos.isEmpty ? "Run Analysis" : "Re-analyze", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: Timeline

    private func timelineCard(_ projection: HealingProjection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Estimated healed", systemImage: "calendar.badge.clock").font(.headline)
            Text(Format.day(projection.estimatedDate))
                .font(.title2.bold())
                .foregroundStyle(Color.accentColor)
            Text(projection.basisDescription)
                .font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: projection.confidence) {
                Text("Confidence").font(.caption2)
            }
            .tint(Color.accentColor)
            if projection.basis == .trend || projection.basis == .blended {
                Text("Estimates improve as you add more photos.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Trend chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Healing trend", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
            Chart {
                ForEach(scoredPhotos) { photo in
                    LineMark(
                        x: .value("Date", photo.captureDate),
                        y: .value("Score", photo.healingScore ?? 0)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Date", photo.captureDate),
                        y: .value("Score", photo.healingScore ?? 0)
                    )
                }
                RuleMark(y: .value("Target", wound.targetScore))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.green.opacity(0.6))
                    .annotation(position: .top, alignment: .leading) {
                        Text("target").font(.caption2).foregroundStyle(.green)
                    }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 180)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Baseline vs latest

    @ViewBuilder
    private var comparisonCard: some View {
        if let baseline = wound.baselinePhoto, let latest = wound.latestPhoto, baseline != latest {
            VStack(alignment: .leading, spacing: 8) {
                Label("Then & now", systemImage: "rectangle.on.rectangle").font(.headline)
                HStack(spacing: 10) {
                    comparePane("Baseline", baseline)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    comparePane("Latest", latest)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func comparePane(_ title: String, _ photo: WoundPhoto) -> some View {
        VStack(spacing: 4) {
            PhotoThumbnail(filename: photo.imageFilename, maxPixel: 400)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            Text(title).font(.caption.bold())
            Text(Format.day(photo.captureDate)).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var disclaimerFooter: some View {
        Text("Healing scores are an on-device estimate from photo color and appearance. They are not a medical diagnosis. When in doubt, consult a healthcare professional.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}
