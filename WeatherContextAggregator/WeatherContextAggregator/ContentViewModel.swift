import Foundation
import Combine
import CoreLocation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var contextData: ContextResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let locationService = LocationService()
    private let contextService  = ContextService()

    func refresh() {
        guard !isLoading else { return }
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let location = try await locationService.fetchLocation()
                let city     = try await locationService.fetchCityName(for: location)
                contextData  = try await contextService.fetchContext(
                    lat:      location.coordinate.latitude,
                    lon:      location.coordinate.longitude,
                    city:     city,
                    timezone: TimeZone.current.identifier
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
