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
                Section("place.details") {
                    TextField("place.name", text: $name)
                        .focused($nameFocused)
                        .accessibilityIdentifier("newPlaceName")
                    TextField("place.street_optional", text: $street)
                    TextField("place.city_optional", text: $city)
                }
                Section("place.location") {
                    Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                        .font(.footnote.monospacedDigit())
                        .textSelection(.enabled)
                }
                Section {
                    Text("community.local_only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("community.add_place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onCancel) {
                        Label("common.cancel", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let place = Place(
                            id: "local-\(UUID().uuidString)",
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            street: street.nilIfBlank,
                            city: city.nilIfBlank,
                            country: String(localized: "country.iraq", locale: locale),
                            coordinate: coordinate
                        )
                        onSave(place)
                    } label: {
                        Label("common.save", systemImage: "checkmark")
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
