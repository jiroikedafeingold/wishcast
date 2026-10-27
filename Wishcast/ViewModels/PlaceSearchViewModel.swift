import Foundation
import Observation

@Observable
final class PlaceSearchViewModel {
    var query = ""
    private(set) var results: [Place] = []

    private let client = OpenMeteoClient()

    /// Call from `.task(id: query)` so each keystroke cancels the previous search.
    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        // Debounce typing.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, let places = try? await client.searchPlaces(trimmed) else { return }
        results = places
    }
}
