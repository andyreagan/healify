import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var wounds: [Wound]
    @State private var path: [UUID] = []
    @State private var showingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            BodyDashboardView(path: $path)
                .navigationTitle("Healify")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let wound = wounds.first(where: { $0.id == id }) {
                        WoundDetailView(wound: wound)
                    } else {
                        ContentUnavailableView("Wound not found", systemImage: "questionmark")
                    }
                }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .task { seedIfNeeded() }
        }
    }

    private func seedIfNeeded() {
        #if DEBUG
        DebugSeed.seedIfRequested(context)
        DebugSeed.selfTestBackupIfRequested(context)
        if DebugSeed.shouldOpenFirst, path.isEmpty,
           let first = wounds.sorted(by: { $0.createdAt < $1.createdAt }).first {
            path = [first.id]
        }
        #endif
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
        .environmentObject(AppSettings())
        .environmentObject(HealingService())
}
