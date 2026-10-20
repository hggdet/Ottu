import CoreLocation
import SwiftUI

@MainActor
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
    @StateObject private var request = AssistantRequestController<AssistantMessage>()
    private var isWorking: Bool { request.isWorking }
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
        _messages = State(initialValue: [])
    }

    private var currentCoordinate: GeoCoordinate {
        userCoordinate ?? mapCenter
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if messages.isEmpty {
                            welcomeCard
                            promptSuggestions
                        }
                        ForEach(messages) { message in
                            messageView(message)
                                .id(message.id)
                        }
                        if isWorking {
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text(localized("assistant.thinking"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(localized("assistant.cancel")) { request.cancel() }
                                    .font(.subheadline.weight(.semibold))
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .glassEffect(.regular.interactive(), in: Capsule())
                                    .accessibilityIdentifier("assistantCancel")
                            }
                            .padding(14)
                            .background(.background, in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 16)
                            .accessibilityElement(children: .contain)
                        }
                        Color.clear.frame(height: 1).id("assistantBottom")
                    }
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .onChange(of: messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("assistantBottom", anchor: .bottom)
                    }
                }
                .onChange(of: isWorking) { _, working in
                    if working {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("assistantBottom", anchor: .bottom)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        if !messages.isEmpty && !isWorking {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(AssistantQuickPrompt.allCases.prefix(4)) { prompt in
                                        Button(localized(prompt.titleKey)) { send(localized(prompt.titleKey)) }
                                            .font(.caption.weight(.medium))
                                            .buttonStyle(.plain)
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.horizontal, 12)
                                            .frame(minHeight: 44)
                                            .glassEffect(.regular.interactive(), in: Capsule())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                            }
                        }
                        inputBar
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                    .overlay(alignment: .top) { Divider().opacity(0.4) }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localized("assistant.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        request.cancel(notify: false)
                        dismiss()
                    } label: {
                        AppLocalizedText("common.done", locale: locale)
                    }
                }
            }
        }
        .environment(\.layoutDirection, AppLocalization.isRightToLeft(locale) ? .rightToLeft : .leftToRight)
        .onDisappear { request.cancel(notify: false) }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(14)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            Text(localized("assistant.welcome"))
                .font(.title2.bold())
            Text(localized("assistant.intro"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label(localized(userCoordinate == nil ? "assistant.location_missing" : "assistant.location_ready"),
                  systemImage: userCoordinate == nil ? "location.slash" : "location.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private func messageView(_ message: AssistantMessage) -> some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            Text(localized(message.isUser ? "assistant.you" : "assistant.title"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack {
                if message.isUser { Spacer(minLength: 42) }
                Text(message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .foregroundStyle(message.isUser ? Color.white : Color.primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                    )
                if !message.isUser { Spacer(minLength: 42) }
            }

            if let retryText = message.retryText {
                Button {
                    send(retryText, isRetry: true)
                } label: {
                    Label(localized("assistant.retry"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .glassEffect(.regular.interactive(), in: Capsule())
                .disabled(isWorking)
                .accessibilityIdentifier("assistantRetry")
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
                                        .lineLimit(2)
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
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(Text(
                            [place.name, place.subtitle, distanceText(to: place)]
                                .filter { !$0.isEmpty }
                                .joined(separator: ", ")
                        ))
                    }
                }
                .padding(.leading, message.isUser ? 42 : 0)
            }
        }
        .padding(.horizontal, 14)
    }

    private var promptSuggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("assistant.suggestions"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AssistantQuickPrompt.allCases) { prompt in
                    Button {
                        send(localized(prompt.titleKey))
                    } label: {
                        Label(localized(prompt.titleKey), systemImage: prompt.symbol)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14))
                    .disabled(isWorking)
                }
            }
        }
        .padding(.horizontal, 16)
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
                .frame(minHeight: 44)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
                .accessibilityIdentifier("assistantInput")

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .glassEffect(.regular.interactive(), in: Circle())
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            .accessibilityLabel(Text(localized("assistant.send")))
        }
        .padding(.horizontal, 13)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @MainActor
    private func send(_ rawText: String, isRetry: Bool = false) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking else { return }
        if !isRetry { input = "" }
        inputFocused = false
        if !isRetry {
            messages.append(AssistantMessage(text: text, isUser: true, places: nil))
        }
        request.start(operation: {
            try await answer(text)
        }, onCompletion: { outcome in
            switch outcome {
            case .success(let reply):
                messages.append(reply)
            case .failure:
                let failureKey: String
                if case .nearby = AssistantIntentMatcher.match(text) {
                    failureKey = "assistant.nearby_unavailable"
                } else {
                    failureKey = "assistant.service_unavailable"
                }
                messages.append(AssistantMessage(text: localized(failureKey), isUser: false,
                                                 places: nil, retryText: text))
            case .timedOut:
                messages.append(AssistantMessage(text: localized("assistant.timed_out"), isUser: false,
                                                 places: nil, retryText: text))
            case .cancelled:
                messages.append(AssistantMessage(text: localized("assistant.cancelled"), isUser: false,
                                                 places: nil, retryText: text))
            }
        })
    }

    private func answer(_ text: String) async throws -> AssistantMessage {
        try Task.checkCancellation()
        switch AssistantIntentMatcher.match(text) {
        case .nearby(let category):
            guard let userCoordinate else {
                onRequestLocation()
                return AssistantMessage(text: localized("assistant.need_location"), isUser: false, places: nil, retryText: text)
            }
            let places = try await assistantService.nearbyPlaces(
                for: category,
                near: userCoordinate,
                language: language
            )
            guard !places.isEmpty else {
                let categoryName = localized(category.titleKey)
                return AssistantMessage(
                    text: String(format: localized("assistant.no_nearby_format"),
                                 locale: locale, arguments: [categoryName]),
                    isUser: false, places: nil
                )
            }
            return AssistantMessage(
                text: localized("assistant.nearby_results"),
                isUser: false,
                places: places
            )

        case .weather:
            guard let userCoordinate else {
                onRequestLocation()
                return AssistantMessage(text: localized("assistant.need_location"), isUser: false, places: nil, retryText: text)
            }
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

        case .street:
            guard let userCoordinate else {
                onRequestLocation()
                return AssistantMessage(text: localized("assistant.need_location"), isUser: false, places: nil, retryText: text)
            }
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

        case .greeting:
            return reply("assistant.greeting")

        case .search:
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
    var retryText: String? = nil
}

private enum AssistantQuickPrompt: String, CaseIterable, Identifiable {
    case pharmacy, restaurant, cafe, hospital, fuel, hotel, park, market, weather, street

    var id: String { rawValue }
    var titleKey: String { "assistant.prompt.\(rawValue)" }
    var symbol: String {
        switch self {
        case .pharmacy: "cross.case"
        case .restaurant: "fork.knife"
        case .cafe: "cup.and.saucer"
        case .hospital: "cross.circle"
        case .fuel: "fuelpump"
        case .hotel: "bed.double"
        case .park: "tree"
        case .market: "basket"
        case .weather: "cloud.sun"
        case .street: "location"
        }
    }
}

enum AssistantIntent {
    case nearby(AssistantPlaceCategory)
    case weather
    case street
    case greeting
    case search
}

enum AssistantIntentMatcher {
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
