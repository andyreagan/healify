import SwiftUI
import SwiftData

/// The home screen: an anatomical body map with markers for each active wound,
/// and a swipe-up drawer listing them. Both the markers and the list navigate
/// into the wound's timeline.
struct BodyDashboardView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var health: HealthProfileService
    @Query(sort: \Wound.createdAt, order: .reverse) private var wounds: [Wound]

    @Binding var path: [UUID]

    @State private var bodyView: BodyView = .front
    @State private var drawerExpanded = false
    @State private var showingNewWound = false
    @State private var presetRegion: BodyRegion?

    private var active: [Wound] { wounds.filter { !$0.isArchived } }
    private var archived: [Wound] { wounds.filter { $0.isArchived } }

    /// region → number of active wounds there.
    private var markers: [BodyRegion: Int] {
        active.reduce(into: [:]) { acc, wound in
            if let r = wound.bodyRegion { acc[r, default: 0] += 1 }
        }
    }

    var body: some View {
        ZStack {
            BodyMapView(
                shape: health.bodyShape,
                bodyView: $bodyView,
                markers: markers,
                onTapRegion: handleTap
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 150) // keep the figure clear of the collapsed drawer
            .frame(maxHeight: .infinity, alignment: .top)

            BottomDrawer(expanded: $drawerExpanded) {
                drawerContent
            }
        }
        .task { await health.load() }
        .sheet(isPresented: $showingNewWound, onDismiss: { presetRegion = nil }) {
            NewWoundView(presetRegion: presetRegion)
        }
    }

    // MARK: Drawer

    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(active.isEmpty ? "No wounds yet" : "\(active.count) active wound\(active.count == 1 ? "" : "s")")
                    .font(.headline)
                Spacer()
                Button {
                    presetRegion = nil
                    showingNewWound = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill").labelStyle(.titleAndIcon)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if wounds.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(active) { wound in
                        Button { path.append(wound.id) } label: { WoundRow(wound: wound) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { delete(active, at: $0) }

                    if !archived.isEmpty {
                        Section("Healed") {
                            ForEach(archived) { wound in
                                Button { path.append(wound.id) } label: { WoundRow(wound: wound) }
                                    .buttonStyle(.plain)
                            }
                            .onDelete { delete(archived, at: $0) }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Tap a spot on the body to mark a wound, or use Add above.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: Actions

    private func handleTap(_ region: BodyRegion) {
        let here = active.filter { $0.bodyRegion == region }
        switch here.count {
        case 0:
            // Empty spot → start a new wound pre-located here.
            presetRegion = region
            showingNewWound = true
        case 1:
            path.append(here[0].id)
        default:
            // Multiple wounds here → open the list to disambiguate.
            drawerExpanded = true
        }
    }

    private func delete(_ source: [Wound], at offsets: IndexSet) {
        for index in offsets {
            let wound = source[index]
            for photo in wound.photos { ImageStore.delete(photo.imageFilename) }
            context.delete(wound)
        }
    }
}
