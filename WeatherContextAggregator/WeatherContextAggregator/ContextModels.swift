import Foundation

// MARK: - Backend request

struct ContextRequest: Codable {
    let lat: Double
    let lon: Double
    let city: String
    let timezone: String
}

// MARK: - Backend response

struct ContextResponse: Codable {
    let lat: Double
    let lon: Double
    let timezone: String
    let weather: WeatherInfo
    let astronomy: AstronomyInfo
    let locality: LocalityInfo
    let cachedAt: String?
}

struct WeatherInfo: Codable {
    let temperatureC: Double
    let humidityPct: Int
    let windSpeedKmh: Double
    let pollenLevel: String
}

struct AstronomyInfo: Codable {
    let sunrise: String
    let sunset: String
    let solarNoon: String
    let dayLength: String
}

struct LocalityInfo: Codable {
    let city: String
    let localityType: String
    let country: String
    let region: String
    let nearbyFeatures: [String]
}


// MARK: - BigDataCloud client-side reverse geocoding

struct BigDataCloudResponse: Codable {
    let city: String
    let locality: String
}
