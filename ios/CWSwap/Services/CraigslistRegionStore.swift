import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
class CraigslistRegionStore {
    private static let regionsKey = "craigslistRegions"
    private static let termsKey = "craigslistSearchTerms"
    private static let seededKey = "craigslistSeeded_v2"

    var regions: [CraigslistRegion] = []
    var searchTerms: [CraigslistSearchTerm] = []

    var enabledRegions: [CraigslistRegion] {
        regions.filter(\.isEnabled)
    }

    var enabledSearchTerms: [CraigslistSearchTerm] {
        searchTerms.filter(\.isEnabled)
    }

    init() {
        loadFromDefaults()
        if !UserDefaults.standard.bool(forKey: Self.seededKey) {
            seedDefaults()
        }
    }

    // MARK: - Regions

    func toggleRegion(_ region: CraigslistRegion) {
        guard let index = regions.firstIndex(where: { $0.id == region.id }) else { return }
        regions[index].isEnabled.toggle()
        saveToDefaults()
    }

    func addRegion(_ region: CraigslistRegion) {
        guard !regions.contains(where: { $0.id == region.id }) else { return }
        regions.append(region)
        saveToDefaults()
    }

    func removeRegions(at offsets: IndexSet) {
        regions.remove(atOffsets: offsets)
        saveToDefaults()
    }

    // MARK: - Search Terms

    func toggleTerm(_ term: CraigslistSearchTerm) {
        guard let index = searchTerms.firstIndex(where: { $0.id == term.id }) else { return }
        searchTerms[index].isEnabled.toggle()
        saveToDefaults()
    }

    func addTerm(_ term: CraigslistSearchTerm) {
        guard !searchTerms.contains(where: { $0.id == term.id }) else { return }
        searchTerms.append(term)
        saveToDefaults()
    }

    func removeTerms(at offsets: IndexSet) {
        searchTerms.remove(atOffsets: offsets)
        saveToDefaults()
    }

    /// Finds the nearest region to the given coordinates using haversine distance and enables it.
    /// Returns the name of the enabled region, or nil if no regions exist.
    @discardableResult
    func enableNearestRegion(latitude: Double, longitude: Double) -> String? {
        guard !regions.isEmpty else { return nil }

        let userLocation = CLLocation(latitude: latitude, longitude: longitude)
        var closestIndex = 0
        var closestDistance = Double.greatestFiniteMagnitude

        for (index, region) in regions.enumerated() {
            let regionLocation = CLLocation(latitude: region.latitude, longitude: region.longitude)
            let distance = userLocation.distance(from: regionLocation)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }

        regions[closestIndex].isEnabled = true
        saveToDefaults()
        return regions[closestIndex].name
    }

    /// Regions from the default list that aren't already added.
    var availableRegions: [CraigslistRegion] {
        let currentIds = Set(regions.map(\.id))
        return CraigslistConfig.defaultRegions.filter { !currentIds.contains($0.id) }
    }

    // MARK: - Persistence

    /// Reload regions and search terms from UserDefaults.
    /// Call this before scraping to pick up changes made by other store instances (e.g. Settings).
    func reloadFromDefaults() {
        loadFromDefaults()
    }

    private func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: Self.regionsKey) {
            regions = (try? JSONDecoder().decode([CraigslistRegion].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: Self.termsKey) {
            searchTerms = (try? JSONDecoder().decode([CraigslistSearchTerm].self, from: data)) ?? []
        }
    }

    private func saveToDefaults() {
        if let data = try? JSONEncoder().encode(regions) {
            UserDefaults.standard.set(data, forKey: Self.regionsKey)
        }
        if let data = try? JSONEncoder().encode(searchTerms) {
            UserDefaults.standard.set(data, forKey: Self.termsKey)
        }
    }

    private func seedDefaults() {
        regions = CraigslistConfig.defaultRegions
        searchTerms = CraigslistConfig.defaultSearchTerms
        saveToDefaults()
        UserDefaults.standard.set(true, forKey: Self.seededKey)
    }
}
