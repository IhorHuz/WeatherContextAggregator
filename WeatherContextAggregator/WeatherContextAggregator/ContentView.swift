import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                if vm.isLoading {
                    ProgressView("Fetching your context…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let data = vm.contextData {
                    ScrollView {
                        VStack(spacing: 16) {
                            GPSBadge(lat: data.lat, lon: data.lon)
                            WeatherCard(weather: data.weather)
                            AstronomyCard(astronomy: data.astronomy, timezone: data.timezone)
                            LocalityCard(locality: data.locality)
                        }
                        .padding()
                    }

                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 64))
                            .foregroundStyle(.tertiary)
                        Text("Tap Refresh to load your context")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Context Aggregator")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { vm.refresh() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Cards

private struct GPSBadge: View {
    let lat: Double
    let lon: Double

    var body: some View {
        HStack {
            Image(systemName: "location.fill").foregroundStyle(.blue)
            Text(String(format: "%.4f,  %.4f", lat, lon))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

private struct WeatherCard: View {
    let weather: WeatherInfo

    var body: some View {
        Card(title: "Weather") {
            DataRow(icon: "thermometer.medium", label: "Temperature",
                    value: String(format: "%.1f°C", weather.temperatureC))
            DataRow(icon: "humidity",           label: "Humidity",
                    value: "\(weather.humidityPct)%")
            DataRow(icon: "wind",               label: "Wind",
                    value: String(format: "%.1f km/h", weather.windSpeedKmh))
            DataRow(icon: "leaf",               label: "Pollen",
                    value: weather.pollenLevel.capitalized)
        }
    }
}

private struct AstronomyCard: View {
    let astronomy: AstronomyInfo
    let timezone: String

    var body: some View {
        Card(title: "Daylight") {
            DataRow(icon: "sunrise.fill",            label: "Sunrise",    value: astronomy.sunrise)
            DataRow(icon: "sunset.fill",             label: "Sunset",     value: astronomy.sunset)
            DataRow(icon: "sun.max.fill",            label: "Solar noon", value: astronomy.solarNoon)
            DataRow(icon: "hourglass",               label: "Day length", value: astronomy.dayLength)
            DataRow(icon: "clock.arrow.2.circlepath", label: "Timezone",  value: timezone)
        }
    }
}

private struct LocalityCard: View {
    let locality: LocalityInfo

    var body: some View {
        Card(title: "Locality") {
            DataRow(icon: "building.2",         label: "City", value: locality.city)
            DataRow(icon: "map",                label: "Type", value: locality.localityType.capitalized)
            if !locality.nearbyFeatures.isEmpty {
                DataRow(icon: "mappin.and.ellipse", label: "Nearby",
                        value: locality.nearbyFeatures.joined(separator: ", "))
            }
        }
    }
}

// MARK: - Reusable primitives

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct DataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    ContentView()
}
