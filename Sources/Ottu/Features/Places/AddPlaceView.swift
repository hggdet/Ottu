import SwiftUI

struct AddPlaceView: View {
    @Environment(\.locale) private var locale
    let coordinate: GeoCoordinate
    let onSave: (Place) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var street = ""
    @State private var city = ""
    @FocusState private var nameFocused: Bool

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AppLocalization.string("place.name", locale: locale), text: $name)
                        .focused($nameFocused)
                        .accessibilityIdentifier("newPlaceName")
                    TextField(AppLocalization.string("place.street_optional", locale: locale), text: $street)
                    TextField(AppLocalization.string("place.city_optional", locale: locale), text: $city)
                } header: {
                    AppLocalizedText("place.details", locale: locale)
                }
                Section {
                    Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                        .font(.footnote.monospacedDigit())
                        .textSelection(.enabled)
                } header: {
                    AppLocalizedText("place.location", locale: locale)
                }
                Section {
                    AppLocalizedText("community.local_only", locale: locale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Text(AppLocalization.string("community.add_place", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onCancel) {
                        AppLocalizedLabel("common.cancel", systemImage: "xmark", locale: locale)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let place = Place(
                            id: "local-\(UUID().uuidString)",
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            street: street.nilIfBlank,
                            city: city.nilIfBlank,
                            country: AppLocalization.string("country.iraq", locale: locale),
                            coordinate: coordinate
                        )
                        onSave(place)
                    } label: {
                        AppLocalizedLabel("common.save", systemImage: "checkmark", locale: locale)
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear { nameFocused = true }
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
