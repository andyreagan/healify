import SwiftUI
import SwiftData
import PhotosUI

/// One wound, one screen: a compact healing summary on top, a single
/// chronological timeline mixing photos and notes, and centered primary actions
/// (Add Note is the clear first action).
struct WoundDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var healingService: HealingService

    @Bindable var wound: Wound

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var showingPhotoSource = false
    @State private var showingEdit = false
    @State private var showingAddNote = false
    @State private var editingNote: JournalNote?
    @State private var importing = false

    /// A merged, newest-first timeline of photos and notes.
    private enum Entry: Identifiable {
        case photo(WoundPhoto)
        case note(JournalNote)
        var date: Date {
            switch self {
            case .photo(let p): return p.captureDate
            case .note(let n): return n.timestamp
            }
        }
        var id: String {
            switch self {
            case .photo(let p): return "p-\(p.id)"
            case .note(let n): return "n-\(n.id)"
            }
        }
    }

    private var entries: [Entry] {
        (wound.photos.map(Entry.photo) + wound.notes.map(Entry.note))
            .sorted { $0.date > $1.date }
    }

    private var isEmpty: Bool { wound.photos.isEmpty && wound.notes.isEmpty }

    var body: some View {
        Group {
            if isEmpty {
                emptyState
            } else {
                timeline
            }
        }
        .navigationTitle(wound.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            if !isEmpty { actionBar }
        }
        // Photo source: confirmation dialog drives separate, reliable presenters
        // (PhotosPicker as a modifier — NOT nested in a Menu, which fails to open).
        .confirmationDialog("Add Photo", isPresented: $showingPhotoSource, titleVisibility: .visible) {
            if CameraPicker.isAvailable {
                Button("Take Photo") { showingCamera = true }
            }
            Button("Choose from Library") { showingLibrary = true }
        }
        .photosPicker(isPresented: $showingLibrary, selection: $pickerItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: pickerItems) { _, items in importPicked(items) }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                if let photo = PhotoImporter.importCameraImage(image, into: wound, context: context) {
                    afterAdd(photo)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingEdit) { NewWoundView(existing: wound) }
        .sheet(isPresented: $showingAddNote) { AddNoteView(wound: wound) }
        .sheet(item: $editingNote) { note in AddNoteView(wound: wound, existing: note) }
    }

    // MARK: Timeline

    private var timeline: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavigationLink {
                    OverviewView(wound: wound)
                } label: {
                    HealingSummaryCard(wound: wound)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                if importing {
                    HStack { ProgressView(); Text("Importing…").foregroundStyle(.secondary) }
                        .padding(.horizontal)
                }

                ForEach(entries) { entry in
                    timelineRow(entry)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func timelineRow(_ entry: Entry) -> some View {
        switch entry {
        case .photo(let photo):
            NavigationLink {
                PhotoDetailView(photo: photo, wound: wound)
            } label: {
                PhotoTimelineCard(photo: photo, wound: wound)
            }
            .buttonStyle(.plain)
        case .note(let note):
            Button {
                editingNote = note
            } label: {
                NoteCard(note: note)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Empty state — centered primary actions

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: wound.kind.symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text(wound.name).font(.title2.bold())
                if !wound.locationDescription.isEmpty {
                    Text(wound.locationDescription).foregroundStyle(.secondary)
                }
                Text("Start by adding a note about how it looks and feels today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    showingAddNote = true
                } label: {
                    Label("Add Note", systemImage: "square.and.pencil")
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showingPhotoSource = true
                } label: {
                    Label("Add Photo", systemImage: "camera")
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Persistent action bar (non-empty)

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                showingAddNote = true
            } label: {
                Label("Add Note", systemImage: "square.and.pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingPhotoSource = true
            } label: {
                Label("Add Photo", systemImage: "camera").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                OverviewView(wound: wound)
            } label: {
                Image(systemName: "chart.xyaxis.line")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showingEdit = true } label: { Label("Edit Wound", systemImage: "pencil") }
                Button {
                    wound.isArchived.toggle()
                } label: {
                    Label(wound.isArchived ? "Mark Active" : "Mark Healed",
                          systemImage: wound.isArchived ? "arrow.uturn.backward" : "checkmark.seal")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: Photo import

    private func importPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        importing = true
        Task {
            var last: WoundPhoto?
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let photo = PhotoImporter.importData(data, into: wound, context: context) {
                    last = photo
                }
            }
            pickerItems = []
            importing = false
            if let last { afterAdd(last) }
        }
    }

    private func afterAdd(_ photo: WoundPhoto) {
        try? context.save()
        if settings.aiScoringEnabled && settings.autoAnalyzeOnAdd {
            Task { await healingService.analyze(wound, in: context) }
        }
    }
}

/// Compact healing summary shown atop the timeline. Tapping opens the full
/// analysis; when AI is off, it's a slim opt-in prompt.
private struct HealingSummaryCard: View {
    @EnvironmentObject private var settings: AppSettings
    let wound: Wound

    var body: some View {
        if settings.aiScoringEnabled {
            HStack(spacing: 16) {
                ScoreRing(score: wound.latestScore ?? 0, size: 64, lineWidth: 7)
                VStack(alignment: .leading, spacing: 4) {
                    if let projection = HealingTimeline.project(for: wound) {
                        Text("Est. healed \(Format.day(projection.estimatedDate))").font(.subheadline.bold())
                        Text(projection.basisDescription).font(.caption).foregroundStyle(.secondary)
                    } else if wound.latestScore != nil {
                        Text("Add more photos for a timeline estimate.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Open analysis to compute a score.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        } else {
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(Color.accentColor)
                Text("Turn on on-device healing analysis").font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// A photo entry in the timeline.
private struct PhotoTimelineCard: View {
    @EnvironmentObject private var settings: AppSettings
    let photo: WoundPhoto
    let wound: Wound

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoThumbnail(filename: photo.imageFilename, maxPixel: 700, cornerRadius: 14)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .overlay(alignment: .topLeading) {
                    if photo == wound.baselinePhoto {
                        tag("Baseline", .ultraThinMaterial)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if settings.aiScoringEnabled, let score = photo.healingScore {
                        Text("\(Int(score))")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(score.scoreColor, in: Capsule())
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
            HStack {
                Label("Photo", systemImage: "camera").font(.caption.bold()).foregroundStyle(.secondary)
                if !photo.caption.isEmpty {
                    Text(photo.caption).font(.subheadline).lineLimit(1)
                }
                Spacer()
                Text(Format.dayTime(photo.captureDate)).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private func tag(_ text: String, _ bg: Material) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(bg, in: Capsule())
            .padding(8)
    }
}
