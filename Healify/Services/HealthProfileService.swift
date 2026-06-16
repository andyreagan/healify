import Foundation
import HealthKit

/// Reads minimal demographics from Apple Health to shape the body-map
/// silhouette. Only reads biological sex and date of birth — never writes — and
/// degrades gracefully to a neutral figure if Health is unavailable or the user
/// declines.
@MainActor
final class HealthProfileService: ObservableObject {
    @Published private(set) var bodyShape: BodyShape = .neutral
    @Published private(set) var age: Int?
    @Published private(set) var didRequest = false

    private let store = HKHealthStore()

    var isHealthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read access (idempotent) and loads characteristics. Safe to call
    /// repeatedly; only prompts the first time.
    func load() async {
        // Escape hatch for automated/headless runs to avoid the auth modal.
        if ProcessInfo.processInfo.environment["HEALIFY_NO_HEALTH"] == "1" { return }
        guard isHealthAvailable else { return }
        let types: Set<HKObjectType> = [
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            didRequest = true
            readCharacteristics()
        } catch {
            // Authorization failed or was dismissed — keep neutral defaults.
            didRequest = true
        }
    }

    private func readCharacteristics() {
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .male: bodyShape = .masculine
            case .female: bodyShape = .feminine
            default: bodyShape = .neutral
            }
        }
        if let components = try? store.dateOfBirthComponents(),
           let birthDate = Calendar.current.date(from: components) {
            age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year
        }
    }
}
