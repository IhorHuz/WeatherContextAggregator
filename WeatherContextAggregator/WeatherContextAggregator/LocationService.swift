import CoreLocation

enum LocationError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Location access denied. Enable it in Settings > Privacy > Location Services."
    }
}

final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fetchLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
                // locationManagerDidChangeAuthorization will call requestLocation once granted
            case .denied, .restricted:
                cont.resume(throwing: LocationError.permissionDenied)
                continuation = nil
            @unknown default:
                cont.resume(throwing: LocationError.permissionDenied)
                continuation = nil
            }
        }
    }

    /// Reverse-geocodes a location to a city name via BigDataCloud's client-side API.
    func fetchCityName(for location: CLLocation) async throws -> String {
        var comps = URLComponents(string: "https://api.bigdatacloud.net/data/reverse-geocode-client")!
        comps.queryItems = [
            URLQueryItem(name: "latitude",        value: "\(location.coordinate.latitude)"),
            URLQueryItem(name: "longitude",       value: "\(location.coordinate.longitude)"),
            URLQueryItem(name: "localityLanguage", value: "en"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(BigDataCloudResponse.self, from: data)
        let name = decoded.city.isEmpty ? decoded.locality : decoded.city
        return name.isEmpty ? "Unknown" : name
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations[0])
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.permissionDenied)
            continuation = nil
        default:
            break
        }
    }
}
