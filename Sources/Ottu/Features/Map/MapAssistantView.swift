import CoreLocation
import SwiftUI

struct MapAssistantView: View {
    let userCoordinate: GeoCoordinate?
    let mapCenter: GeoCoordinate
    let language: String
    let locale: Locale
    let searchService: any PlaceSearchProviding
    let assistantService: any MapAssistantProviding
    let onRequestLocation: () -> Void
    let onSelectPlace: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [AssistantMessage]
    @State private var input = ""
    @State private var isWorking = false
    @AppStorage("ottu.distanceUnit") private var distanceUnit = "km"
    @FocusState private var inputFocused: Bool

    init(
        userCoordinate: GeoCoordinate?,
        mapCenter: GeoCoordinate,
        language: String,
        locale: Locale,
        searchService: any PlaceSearchProviding,
        assistantService: any MapAssistantProviding,
        onRequestLocation: @escaping () -> Void,
        onSelectPlace: @escaping (Place) -> Void
    ) {
        self.userCoordinate = userCoordinate
        self.mapCenter = mapCenter
        self.language = language
        self.locale = locale
        self.searchService = searchService
        self.assistantService = assistantService
        self.onRequestLocation = onRequestLocation
        self.onSelectPlace = onSelectPlace
        _messages = State(initialValue: [
            AssistantMessage(
                text: AppLocalization.string("assistant.intro", locale: locale),
                isUser: false,
                places: nil
            )
        ])
    }

    private var currentCoordinate: GeoCoordinate {
        userCoordinate ?? mapCenter
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                messageView(message)
                                    .id(message.id)
                            }
                            if isWorking {
                                HStack(spacing: 7) {
                                    ProgressView().controlSize(.small)
                                    Text(localized("assistant.thinking"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 32)
                                }
                                .padding(.horizontal, 14)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .onChange(of: messages.count) { _, _ in
                        guard let last = messages.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                promptSuggestions
                inputBar
            }
            .navigationTitle(localized("assistant.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        AppLocalizedText("common.done", locale: locale)
                    }
                }
            }
        }
    }

    private func messageView(_ message: AssistantMessage) -> some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 7) {
            HStack {
                if message.isUser { Spacer(minLength: 42) }
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.isUser ? Color.white : Color.primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser ? Color.accentColor : Color.primary.opacity(0.075),
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                    )
                if !message.isUser { Spacer(minLength: 42) }
            }

            if let places = message.places {
                VStack(spacing: 7) {
                    ForEach(places) { place in
                        Button {
                            inputFocused = false
                            onSelectPlace(place)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if !place.subtitle.isEmpty {
                                        Text(place.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                                Text(distanceText(to: place))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(place.name))
                    }
                }
                .padding(.leading, message.isUser ? 42 : 0)
            }
        }
        .padding(.horizontal, 14)
    }

    private var promptSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AssistantQuickPrompt.allCases) { prompt in
                    Button {
                        send(localized(prompt.titleKey))
                    } label: {
                        Text(localized(prompt.titleKey))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.11), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .top) { Divider().opacity(0.35) }
    }

    private var inputBar: some View {
        HStack(spacing: 9) {
            TextField(localized("assistant.placeholder"), text: $input, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(.send)
                .onSubmit { send(input) }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.primary.opacity(0.07), in: Capsule())
                .accessibilityIdentifier("assistantInput")

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            .accessibilityLabel(Text(localized("assistant.send")))
        }
        .padding(.horizontal, 13)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking else { return }
        input = ""
        inputFocused = false
        messages.append(AssistantMessage(text: text, isUser: true, places: nil))
        isWorking = true

        Task { @MainActor in
            let reply = await answer(text)
            messages.append(reply)
            isWorking = false
        }
    }

    private func answer(_ text: String) async -> AssistantMessage {
        switch AssistantIntentMatcher.match(text) {
        case .nearby(let category):
            guard let userCoordinate else {
                onRequestLocation()
                return reply("assistant.need_location")
            }
            do {
                let places = try await assistantService.nearbyPlaces(
                    for: category,
                    near: userCoordinate,
                    language: language
                )
                guard !places.isEmpty else {
                    let categoryName = localized(category.titleKey)
                    return reply(
                        String(
                            format: localized("assistant.no_nearby_format"),
                            locale: locale,
                            arguments: [categoryName]
                        )
                    )
                }
                return AssistantMessage(
                    text: localized("assistant.nearby_results"),
                    isUser: false,
                    places: places
                )
            } catch {
                return reply("assistant.service_unavailable")
            }

        case .weather:
            guard let userCoordinate else {
                onRequestLocation()
                return reply("assistant.need_location")
            }
            do {
                let weather = try await assistantService.weather(at: userCoordinate)
                let condition = localized(weatherConditionKey(for: weather.weatherCode))
                var response = String(
                    format: localized("assistant.weather_format"),
                    locale: locale,
                    arguments: [condition, weather.temperatureCelsius]
                )
                let times = [
                    weather.sunrise.map { "\(localized("assistant.sunrise")) \($0)" },
                    weather.sunset.map { "\(localized("assistant.sunset")) \($0)" }
                ].compactMap { $0 }
                if !times.isEmpty { response += " · " + times.joined(separator: " · ") }
                return AssistantMessage(text: response, isUser: false, places: nil)
            } catch {
                return reply("assistant.service_unavailable")
            }

        case .street:
            guard let userCoordinate else {
                onRequestLocation()
                return reply("assistant.need_location")
            }
            do {
                guard let street = try await assistantService.nearbyStreet(
                    at: userCoordinate,
                    language: language
                ) else {
                    return reply("assistant.street_not_found")
                }
                return AssistantMessage(
                    text: String(
                        format: localized("assistant.street_format"),
                        locale: locale,
                        arguments: [street]
                    ),
                    isUser: false,
                    places: nil
                )
            } catch {
                return reply("assistant.service_unavailable")
            }

        case .greeting:
            return reply("assistant.greeting")

        case .search:
            do {
                let places = try await searchService.search(
                    text,
                    near: currentCoordinate,
                    language: language
                )
                guard !places.isEmpty else {
                    return AssistantMessage(
                        text: String(
                            format: localized("assistant.search_empty_format"),
                            locale: locale,
                            arguments: [text]
                        ),
                        isUser: false,
                        places: nil
                    )
                }
                return AssistantMessage(
                    text: String(
                        format: localized("assistant.search_results_format"),
                        locale: locale,
                        arguments: [text]
                    ),
                    isUser: false,
                    places: places
                )
            } catch {
                return reply("assistant.service_unavailable")
            }
        }
    }

    private func reply(_ key: String) -> AssistantMessage {
        AssistantMessage(text: localized(key), isUser: false, places: nil)
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }

    private func distanceText(to place: Place) -> String {
        let origin = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        let destination = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let meters = origin.distance(from: destination)
        let usesMiles = distanceUnit == "mi"
        if usesMiles {
            return String(format: "%.1f mi", meters / 1_609.344)
        }
        return meters < 1_000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1_000)
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
}

private struct AssistantMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let places: [Place]?
}

private enum AssistantQuickPrompt: String, CaseIterable, Identifiable {
    case pharmacy, restaurant, cafe, hospital, fuel, hotel, park, market, weather, street

    var id: String { rawValue }
    var titleKey: String { "assistant.prompt.\(rawValue)" }
}

private enum AssistantIntent {
    case nearby(AssistantPlaceCategory)
    case weather
    case street
    case greeting
    case search
}

private enum AssistantIntentMatcher {
    static func match(_ text: String) -> AssistantIntent {
        let normalized = normalize(text)
        for category in AssistantPlaceCategory.allCases {
            if category.intentTerms.contains(where: { normalized.contains(normalize($0)) }) {
                return .nearby(category)
            }
        }

        if containsAny(normalized, ["طقس", "الجو", "جو اليوم", "مطر", "حر", "بارد", "weather", "rain", "temperature", "forecast", "کەش", "باران", "هەوا"]) {
            return .weather
        }
        if containsAny(normalized, ["وين اني", "وين انا", "اين انا", "موقعي", "قريب مني", "شارع", "where am i", "my location", "nearby street", "street near", "location", "لە کوێم", "شوێنی من", "شەقام"]) {
            return .street
        }
        if containsAny(normalized, ["سلام", "هلا", "مرحبا", "اهلا", "hello", "hi", "شلونك", "how are you", "سڵاو"]) {
            return .greeting
        }
        return .search
    }

    private static func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains(normalize($0)) }
    }

    private static func normalize(_ text: String) -> String {
        var result = text.lowercased()
        for mark in ["\u{0640}", "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}", "\u{0650}", "\u{0651}", "\u{0652}", "\u{0653}", "\u{0654}", "\u{0655}", "\u{0670}"] {
            result = result.replacingOccurrences(of: mark, with: "")
        }
        for (source, replacement) in [("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ة", "ه"), ("ى", "ي"), ("ؤ", "و"), ("ئ", "ي"), ("ک", "ك"), ("ی", "ي")] {
            result = result.replacingOccurrences(of: source, with: replacement)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
