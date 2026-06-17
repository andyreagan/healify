import SwiftUI
import SwiftData

/// The home screen: an anatomical body map with markers for each active wound,
/// and a swipe-up drawer listing them. Both the markers and the list navigate
/// into the wound's timeline.
struct BodyDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Wound.createdAt, order: .reverse) private var wounds: [Wound]

    @Binding var path: [UUID]

    @State private var bodyView: BodyView = .front
    @State private var drawerExpanded = false
    /// Item-driven sheet so the tapped region is reliably passed (an
    /// isPresented sheet can capture a stale preset).
    @State private var newWoundRequest: NewWoundRequest?
    /// Set when a wound is created, so we can navigate to it after the sheet
    /// dismisses.
    @State private var createdWoundID: UUID?
    @State private var showingBulkWounds = false
    @State private var showingBulkNote = false

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
                bodyView: $bodyView,
                markers: markers,
                onTapRegion: handleTap
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 150) // keep the figure clear of the collapsed drawer
            .frame(maxHeight: .infinity, alignment: .top)

            BottomDrawer(expanded: $drawerExpanded, minHeight: wounds.isEmpty ? 165 : 130) {
                drawerContent
            }
        }
        #if DEBUG
        .task {
            if ProcessInfo.processInfo.environment["HEALIFY_OPEN_NEW"] == "1", newWoundRequest == nil {
                newWoundRequest = NewWoundRequest(region: BodyRegion(part: .forearm, side: .right, view: .front))
            }
        }
        #endif
        .sheet(item: $newWoundRequest, onDismiss: navigateToCreatedWound) { request in
            NewWoundView(presetRegion: request.region, onCreate: { createdWoundID = $0.id })
        }
        .sheet(isPresented: $showingBulkWounds) { BulkAddWoundsView() }
        .sheet(isPresented: $showingBulkNote) { BulkAddNoteView() }
    }

    /// Push the just-created wound's timeline so the user lands there ready to
    /// add a note or photo.
    private func navigateToCreatedWound() {
        if let id = createdWoundID {
            path.append(id)
            createdWoundID = nil
        }
    }

    // MARK: Drawer

    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(active.isEmpty ? "No wounds yet" : "\(active.count) active wound\(active.count == 1 ? "" : "s")")
                    .font(.headline)
                Spacer()
                Menu {
                    Button {
                        newWoundRequest = NewWoundRequest(region: nil)
                    } label: { Label("One wound", systemImage: "plus") }
                    Button {
                        showingBulkWounds = true
                    } label: { Label("Several wounds…", systemImage: "square.on.square") }
                    if !active.isEmpty {
                        Divider()
                        Button {
                            showingBulkNote = true
                        } label: { Label("Log note for several…", systemImage: "square.and.pencil") }
                    }
                } label: {
                    Label("Add", systemImage: "plus.circle.fill").labelStyle(.titleAndIcon)
                }
                .accessibilityIdentifier("addMenu")
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
        HStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .foregroundStyle(Color.accentColor)
            Text("Tap a spot on the body — or **Add** above — to start your first wound.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: Actions

    private func handleTap(_ region: BodyRegion) {
        let here = active.filter { $0.bodyRegion == region }
        switch here.count {
        case 0:
            // Empty spot → start a new wound pre-located here.
            newWoundRequest = NewWoundRequest(region: region)
        case 1:
            path.append(here[0].id)
        default:
            // Multiple wounds here → open the list to disambiguate.
            drawerExpanded = true
        }
    }

    private func delete(_ source: [Wound], at offsets: IndexSet) {
        for index in offsets {
            Persistence.delete(source[index], from: context)
        }
    }
}

/// Identifiable wrapper so the new-wound sheet is item-driven (carries the
/// tapped region reliably).
private struct NewWoundRequest: Identifiable {
    let id = UUID()
    let region: BodyRegion?
}
