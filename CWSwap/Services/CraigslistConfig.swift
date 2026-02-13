import Foundation

enum CraigslistConfig {
    /// HTML search URL for a region + query. Category "sss" = all for sale.
    static func searchURL(region: String, query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(region).craigslist.org"
        components.path = "/search/sss"
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
        ]
        return components.url
    }

    static let pageSize = 25

    /// Delay between detail page fetches per region to avoid blocks.
    static let detailFetchDelay: TimeInterval = 0.5

    /// Maximum concurrent detail page fetches.
    static let maxConcurrentDetailFetches = 5

    static let defaultRegions: [CraigslistRegion] = [
        CraigslistRegion(id: "newyork", name: "New York", isEnabled: false, latitude: 40.7128, longitude: -74.0060),
        CraigslistRegion(id: "losangeles", name: "Los Angeles", isEnabled: false, latitude: 34.0522, longitude: -118.2437),
        CraigslistRegion(id: "chicago", name: "Chicago", isEnabled: false, latitude: 41.8781, longitude: -87.6298),
        CraigslistRegion(id: "houston", name: "Houston", isEnabled: false, latitude: 29.7604, longitude: -95.3698),
        CraigslistRegion(id: "phoenix", name: "Phoenix", isEnabled: false, latitude: 33.4484, longitude: -112.0740),
        CraigslistRegion(id: "philadelphia", name: "Philadelphia", isEnabled: false, latitude: 39.9526, longitude: -75.1652),
        CraigslistRegion(id: "sanantonio", name: "San Antonio", isEnabled: false, latitude: 29.4241, longitude: -98.4936),
        CraigslistRegion(id: "sandiego", name: "San Diego", isEnabled: false, latitude: 32.7157, longitude: -117.1611),
        CraigslistRegion(id: "dallas", name: "Dallas", isEnabled: false, latitude: 32.7767, longitude: -96.7970),
        CraigslistRegion(id: "austin", name: "Austin", isEnabled: false, latitude: 30.2672, longitude: -97.7431),
        CraigslistRegion(id: "jacksonville", name: "Jacksonville", isEnabled: false, latitude: 30.3322, longitude: -81.6557),
        CraigslistRegion(id: "sfbay", name: "SF Bay Area", isEnabled: false, latitude: 37.7749, longitude: -122.4194),
        CraigslistRegion(id: "seattle", name: "Seattle", isEnabled: false, latitude: 47.6062, longitude: -122.3321),
        CraigslistRegion(id: "denver", name: "Denver", isEnabled: false, latitude: 39.7392, longitude: -104.9903),
        CraigslistRegion(id: "washingtondc", name: "Washington DC", isEnabled: false, latitude: 38.9072, longitude: -77.0369),
        CraigslistRegion(id: "nashville", name: "Nashville", isEnabled: false, latitude: 36.1627, longitude: -86.7816),
        CraigslistRegion(id: "atlanta", name: "Atlanta", isEnabled: false, latitude: 33.7490, longitude: -84.3880),
        CraigslistRegion(id: "boston", name: "Boston", isEnabled: false, latitude: 42.3601, longitude: -71.0589),
        CraigslistRegion(id: "detroit", name: "Detroit", isEnabled: false, latitude: 42.3314, longitude: -83.0458),
        CraigslistRegion(id: "minneapolis", name: "Minneapolis", isEnabled: false, latitude: 44.9778, longitude: -93.2650),
        CraigslistRegion(id: "portland", name: "Portland", isEnabled: false, latitude: 45.5152, longitude: -122.6784),
        CraigslistRegion(id: "lasvegas", name: "Las Vegas", isEnabled: false, latitude: 36.1699, longitude: -115.1398),
        CraigslistRegion(id: "raleigh", name: "Raleigh", isEnabled: false, latitude: 35.7796, longitude: -78.6382),
        CraigslistRegion(id: "stlouis", name: "St. Louis", isEnabled: false, latitude: 38.6270, longitude: -90.1994),
        CraigslistRegion(id: "tampa", name: "Tampa", isEnabled: false, latitude: 27.9506, longitude: -82.4572),
        CraigslistRegion(id: "orlando", name: "Orlando", isEnabled: false, latitude: 28.5383, longitude: -81.3792),
        CraigslistRegion(id: "pittsburgh", name: "Pittsburgh", isEnabled: false, latitude: 40.4406, longitude: -79.9959),
        CraigslistRegion(id: "cincinnati", name: "Cincinnati", isEnabled: false, latitude: 39.1031, longitude: -84.5120),
        CraigslistRegion(id: "kansascity", name: "Kansas City", isEnabled: false, latitude: 39.0997, longitude: -94.5786),
        CraigslistRegion(id: "saltlakecity", name: "Salt Lake City", isEnabled: false, latitude: 40.7608, longitude: -111.8910),
    ]

    static let defaultSearchTerms: [CraigslistSearchTerm] = [
        CraigslistSearchTerm(id: "ham-radio", term: "ham radio", isEnabled: true),
        CraigslistSearchTerm(id: "amateur-radio", term: "amateur radio", isEnabled: true),
        CraigslistSearchTerm(id: "transceiver", term: "transceiver", isEnabled: true),
        CraigslistSearchTerm(id: "hf-antenna", term: "hf antenna", isEnabled: true),
    ]
}
