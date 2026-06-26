import Foundation
import Combine
import CoreLocation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var contextData: ContextResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isShowingCachedData = false

    private let locationService = LocationService()
    private let contextService  = ContextService()
    private let cacheKey = "last_context_response"

    init() {
        loadPersistedData()
    }

    func refresh() {
        guard !isLoading else { return }
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let location = try await locationService.fetchLocation()
                let city     = try await locationService.fetchCityName(for: location)
                let response = try await contextService.fetchContext(
                    lat:      location.coordinate.latitude,
                    lon:      location.coordinate.longitude,
                    city:     city,
                    timezone: TimeZone.current.identifier
                )
                contextData = response
                isShowingCachedData = false
                persistData(response)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func loadPersistedData() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let response = try? JSONDecoder().decode(ContextResponse.self, from: data) else { return }
        contextData = response
        isShowingCachedData = true
    }

    private func persistData(_ response: ContextResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
