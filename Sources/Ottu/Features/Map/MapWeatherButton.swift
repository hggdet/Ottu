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

    private var isUITestWeatherFixture: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ottuUITestWeatherPopoverFixture")
#else
        false
#endif
    }

    private var isLoading: Bool {
        isUITestWeatherFixture
            || (activeLocationID == locationID && weatherLocationID != locationID && failedLocationID != locationID)
    }

    private var didFail: Bool {
        failedLocationID == locationID
    }

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: 7) {
                if didFail {
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 16, weight: .medium))
                } else {
                    weatherIcon(size: 18)
                }
                if let currentWeather {
                    Text(temperatureText(currentWeather.temperatureCelsius))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                } else if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 10)
            .frame(minWidth: 58, minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: Capsule())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("mapWeatherButton")
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
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("mapWeatherLoadingState")
            }
        }
        .padding(16)
        .frame(minWidth: 210, maxWidth: 280, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mapWeatherPopover")
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

#if DEBUG
        // Keep the popover in a stable loading state for the interaction test.
        // No provider request or timer is involved, and Release ignores this flag.
        if ProcessInfo.processInfo.arguments.contains("-ottuUITestWeatherPopoverFixture") {
            return
        }
#endif
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

    private func weatherIcon(size: CGFloat) -> some View {
        Image("FlaticonWeather")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

private struct TaskIdentity: Hashable {
    let locationID: String
    let retryCount: Int
}
