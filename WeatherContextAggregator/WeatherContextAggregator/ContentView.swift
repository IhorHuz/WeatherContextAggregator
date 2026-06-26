import SwiftUI

// MARK: - Sky phase helpers

private func parseMins(_ hhmm: String) -> Int {
    let parts = hhmm.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return 720 }
    return parts[0] * 60 + parts[1]
}

private func currentMins() -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
    return (c.hour ?? 12) * 60 + (c.minute ?? 0)
}

private enum SkyPhase {
    case dawn, morning, day, goldenEvening, dusk, night
}

private func skyPhase(sunrise: String, sunset: String) -> SkyPhase {
    let now  = currentMins()
    let rise = parseMins(sunrise)
    let set  = parseMins(sunset)
    switch now {
    case ..<(rise - 60):            return .night
    case (rise - 60)..<rise:        return .dawn
    case rise..<(rise + 90):        return .morning
    case (rise + 90)..<(set - 90):  return .day
    case (set - 90)..<set:          return .goldenEvening
    case set..<(set + 60):          return .dusk
    default:                        return .night
    }
}

private func skyColors(phase: SkyPhase) -> [Color] {
    switch phase {
    case .dawn:
        return [Color(red: 0.078, green: 0.051, blue: 0.247),
                Color(red: 0.612, green: 0.306, blue: 0.180)]
    case .morning:
        return [Color(red: 0.851, green: 0.482, blue: 0.145),
                Color(red: 0.290, green: 0.627, blue: 0.902)]
    case .day:
        return [Color(red: 0.149, green: 0.522, blue: 0.902),
                Color(red: 0.510, green: 0.780, blue: 1.000)]
    case .goldenEvening:
        return [Color(red: 0.890, green: 0.369, blue: 0.063),
                Color(red: 0.545, green: 0.149, blue: 0.463)]
    case .dusk:
        return [Color(red: 0.243, green: 0.071, blue: 0.408),
                Color(red: 0.659, green: 0.271, blue: 0.125)]
    case .night:
        return [Color(red: 0.031, green: 0.047, blue: 0.176),
                Color(red: 0.067, green: 0.094, blue: 0.278)]
    }
}

// Returns 0 (sunrise) … 1 (sunset), nil at night.
private func sunProgress(sunrise: String, sunset: String) -> Double? {
    let now  = currentMins()
    let rise = parseMins(sunrise)
    let set  = parseMins(sunset)
    guard set > rise, now >= rise, now <= set else { return nil }
    return Double(now - rise) / Double(set - rise)
}

// MARK: - Main view

struct ContentView: View {
    @StateObject private var vm = ContentViewModel()

    private var phase: SkyPhase {
        guard let a = vm.contextData?.astronomy else { return .day }
        return skyPhase(sunrise: a.sunrise, sunset: a.sunset)
    }

    var body: some View {
        let gradient = LinearGradient(
            colors: skyColors(phase: phase),
            startPoint: .top,
            endPoint: .bottom
        )

        NavigationStack {
            ZStack {
                gradient.ignoresSafeArea()

                if vm.isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Fetching your context…")
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let data = vm.contextData {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if vm.isShowingCachedData {
                                OfflineBanner().padding(.bottom, 8)
                            }

                            GPSBadge(lat: data.lat, lon: data.lon)
                                .padding(.bottom, 12)

                            SectionLabel("Weather")
                            WeatherHeroCard(weather: data.weather)
                                .padding(.bottom, 16)

                            SectionLabel("Daylight")
                            AstronomyArcCard(astronomy: data.astronomy, timezone: data.timezone)
                                .padding(.bottom, 16)

                            SectionLabel("Locality")
                            LocalityCard(locality: data.locality)
                        }
                        .padding()
                    }

                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Tap Refresh to load your context")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            // Force dark-variant materials so white text is always readable,
            // regardless of how bright the sky gradient is behind the cards.
            .environment(\.colorScheme, .dark)
            .navigationTitle("Context Aggregator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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

// MARK: - Section label

// Uppercase tracked labels sit outside the glass cards to separate navigation
// chrome from instrument data — two distinct typographic registers.
private struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .kerning(1.5)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
    }
}

// MARK: - GPS badge

private struct GPSBadge: View {
    let lat: Double
    let lon: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
            Text(String(format: "%.4f,  %.4f", lat, lon))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
    }
}

// MARK: - Weather card

private struct WeatherHeroCard: View {
    let weather: WeatherInfo

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", weather.temperatureC))
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("°C")
                        .font(.title2)
                        .fontWeight(.thin)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    StatPill(icon: "humidity",
                             value: "\(weather.humidityPct)%",
                             label: "Humidity")
                    StatPill(icon: "wind",
                             value: String(format: "%.0f km/h", weather.windSpeedKmh),
                             label: "Wind")
                    PollenPill(level: weather.pollenLevel)
                }
            }
        }
    }
}

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PollenPill: View {
    let level: String

    private var accentColor: Color {
        switch level.lowercased() {
        case "low":      return Color(red: 0.3,  green: 0.85, blue: 0.4)
        case "moderate": return Color(red: 0.95, green: 0.80, blue: 0.2)
        case "high":     return Color(red: 0.95, green: 0.35, blue: 0.3)
        default:         return .white.opacity(0.5)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.title3)
                .foregroundStyle(accentColor)
            Text(level.capitalized)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("Pollen")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Astronomy card

private struct AstronomyArcCard: View {
    let astronomy: AstronomyInfo
    let timezone: String

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                SunArc(progress: sunProgress(sunrise: astronomy.sunrise,
                                             sunset: astronomy.sunset))
                    .frame(height: 90)

                HStack {
                    AstroTime(icon: "sunrise.fill",
                              color: .orange,
                              label: "Sunrise",
                              value: astronomy.sunrise)
                    Spacer()
                    AstroTime(icon: "sun.max.fill",
                              color: Color(red: 0.957, green: 0.784, blue: 0.259),
                              label: "Solar noon",
                              value: astronomy.solarNoon)
                    Spacer()
                    AstroTime(icon: "sunset.fill",
                              color: .orange,
                              label: "Sunset",
                              value: astronomy.sunset)
                }

                Divider().background(.white.opacity(0.2))

                HStack(spacing: 16) {
                    Label(astronomy.dayLength, systemImage: "hourglass")
                    Spacer()
                    Label(timezone, systemImage: "clock.arrow.2.circlepath")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

private struct AstroTime: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: - Sun arc

private struct SunArc: View {
    let progress: Double?
    @State private var glowScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let w  = geo.size.width
            let h  = geo.size.height
            let cx = w / 2
            let cy = h
            let r  = min(w / 2, h)

            let arcPath = Path { p in
                p.addArc(center: CGPoint(x: cx, y: cy),
                         radius: r,
                         startAngle: .degrees(180),
                         endAngle: .degrees(0),
                         clockwise: false)
            }

            ZStack {
                arcPath
                    .stroke(.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))

                if let t = progress {
                    let angleRad = Double.pi * (1.0 - t)
                    let sunX = cx + r * cos(angleRad)
                    let sunY = cy - r * sin(angleRad)

                    // Outer ripple
                    Circle()
                        .fill(Color(red: 0.957, green: 0.784, blue: 0.259).opacity(0.15))
                        .frame(width: 30, height: 30)
                        .scaleEffect(glowScale * 1.5)
                        .position(x: sunX, y: sunY)

                    // Inner glow
                    Circle()
                        .fill(Color(red: 0.957, green: 0.784, blue: 0.259).opacity(0.35))
                        .frame(width: 30, height: 30)
                        .scaleEffect(glowScale)
                        .position(x: sunX, y: sunY)

                    // Sun dot
                    Circle()
                        .fill(Color(red: 0.957, green: 0.784, blue: 0.259))
                        .frame(width: 16, height: 16)
                        .position(x: sunX, y: sunY)

                } else {
                    Image(systemName: "moon.stars.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                        .position(x: cx, y: cy - r)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowScale = 1.5
                }
            }
        }
    }
}

// MARK: - Locality card

private struct LocalityCard: View {
    let locality: LocalityInfo

    private var typeCountryLine: String {
        [locality.localityType.capitalized, locality.country]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // City is the anchor — give it the size it deserves
                VStack(alignment: .leading, spacing: 2) {
                    Text(locality.city)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    if !typeCountryLine.isEmpty {
                        Text(typeCountryLine)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if !locality.region.isEmpty {
                    Divider().background(.white.opacity(0.2))
                    Label(locality.region, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                if !locality.nearbyFeatures.isEmpty {
                    Label(locality.nearbyFeatures.joined(separator: " · "),
                          systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }
}

// MARK: - Offline banner

private struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing last saved data")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.8))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Primitives

private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}
