import SwiftUI

struct MapWeatherButton: View {
    let coordinate: GeoCoordinate
    let locale: Locale
    let assistantService: any MapAssistantProviding

    @State private var weather: AssistantWeather?
    @State private var weatherLocationID: String?
    @State private var failedLocationID: String?
    @State private var activeLocationID: String?
    @State private var retryCount = 0
    @State private var isPopoverPresented = false

    private var locationID: String {
        String(
            format: "%.2f|%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.latitude,
            coordinate.longitude
        )
    }

    private var currentWeather: AssistantWeather? {
        weatherLocationID == locationID ? weather : nil
    }

    private var isLoading: Bool {
        activeLocationID == locationID && weatherLocationID != locationID && failedLocationID != locationID
    }

    private var didFail: Bool {
        failedLocationID == locationID
    }

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            Group {
                if let currentWeather {
                    VStack(spacing: 1) {
                        Image(systemName: symbolName(for: currentWeather.weatherCode))
                            .font(.system(size: 16, weight: .medium))
                        Text(temperatureText(currentWeather.temperatureCelsius))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                } else if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if didFail {
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 18, weight: .medium))
                } else {
                    Image(systemName: "cloud")
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .foregroundStyle(Color.primary)
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: Circle())
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            weatherPopover
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: locationID) { _, newLocationID in
            activeLocationID = newLocationID
            weather = nil
            weatherLocationID = nil
            failedLocationID = nil
        }
        .task(id: TaskIdentity(locationID: locationID, retryCount: retryCount)) {
            await loadWeather(at: coordinate, locationID: locationID)
        }
    }

    private var weatherPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let currentWeather {
                Text(weatherSummary(currentWeather))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if didFail {
                Text(localized("assistant.service_unavailable"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: retry) {
                    Label(localized("search.retry"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localized("assistant.thinking"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 210, maxWidth: 280, alignment: .leading)
    }

    private var accessibilityLabel: String {
        if let currentWeather {
            weatherSummary(currentWeather)
        } else if didFail {
            localized("assistant.service_unavailable")
        } else {
            localized("assistant.thinking")
        }
    }

    @MainActor
    private func loadWeather(at coordinate: GeoCoordinate, locationID: String) async {
        activeLocationID = locationID
        weather = nil
        weatherLocationID = nil
        failedLocationID = nil

        do {
            let result = try await assistantService.weather(at: coordinate)
            guard !Task.isCancelled, activeLocationID == locationID else { return }
            weather = result
            weatherLocationID = locationID
        } catch {
            guard !Task.isCancelled, activeLocationID == locationID else { return }
            weather = nil
            weatherLocationID = nil
            failedLocationID = locationID
        }
    }

    private func retry() {
        weather = nil
        weatherLocationID = nil
        failedLocationID = nil
        activeLocationID = locationID
        retryCount += 1
    }

    private func weatherSummary(_ weather: AssistantWeather) -> String {
        String(
            format: localized("assistant.weather_format"),
            locale: locale,
            arguments: [localized(weatherConditionKey(for: weather.weatherCode)), weather.temperatureCelsius]
        )
    }

    private func temperatureText(_ celsius: Double) -> String {
        String(format: "%.0f°", locale: locale, celsius)
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }

    private func weatherConditionKey(for code: Int) -> String {
        switch code {
        case 0: "assistant.weather.clear"
        case 1, 2: "assistant.weather.partly_cloudy"
        case 3: "assistant.weather.cloudy"
        case 45, 48: "assistant.weather.fog"
        case 51, 53, 55: "assistant.weather.drizzle"
        case 61, 63, 65, 80, 81, 82: "assistant.weather.rain"
        case 66, 67: "assistant.weather.freezing_rain"
        case 71, 73, 75, 77, 85, 86: "assistant.weather.snow"
        case 95, 96, 99: "assistant.weather.storm"
        default: "assistant.weather.unknown"
        }
    }

    private func symbolName(for code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55: "cloud.drizzle.fill"
        case 61, 63, 65, 80, 81, 82: "cloud.rain.fill"
        case 66, 67: "cloud.sleet.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}

private struct TaskIdentity: Hashable {
    let locationID: String
    let retryCount: Int
}
