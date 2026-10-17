import SwiftUI

struct QuickStopPickerSheet: View {
    @Environment(\.locale) private var locale

    let places: [Place]
    let selectedCategory: AssistantPlaceCategory?
    let isSearching: Bool
    let errorMessage: String?
    let glassIntensity: Double
    let onSearch: (AssistantPlaceCategory) -> Void
    let onSelect: (Place) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    AppLocalizedText("navigation.stop_title", locale: locale)
                        .font(.title3.weight(.bold))
                    AppLocalizedText("navigation.stop_hint", locale: locale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AppLocalization.string("common.close", locale: locale)))
            }

            HStack(spacing: 9) {
                categoryButton(.fuel)
                categoryButton(.cafe)
            }

            if isSearching {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    AppLocalizedText("navigation.stop_searching", locale: locale)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(13)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
            } else if selectedCategory == nil {
                AppLocalizedText("navigation.stop_hint", locale: locale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
            } else if places.isEmpty {
                AppLocalizedText("navigation.stop_empty", locale: locale)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(places) { place in
                            Button {
                                onSelect(place)
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: selectedCategory == .fuel ? "fuelpump.fill" : "cup.and.saucer.fill")
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 26)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(place.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        if !place.subtitle.isEmpty {
                                            Text(place.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tint)
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 11)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if place.id != places.last?.id { Divider().padding(.leading, 48) }
                        }
                    }
                }
                .frame(maxHeight: 250)
                .mapGlassSurface(cornerRadius: 20, glassIntensity: glassIntensity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mapGlassSurface(cornerRadius: 28, glassIntensity: glassIntensity)
        .accessibilityElement(children: .contain)
    }

    private func categoryButton(_ category: AssistantPlaceCategory) -> some View {
        let selected = selectedCategory == category
        let titleKey = category.titleKey
        let symbol = category == .fuel ? "fuelpump.fill" : "cup.and.saucer.fill"
        return Button {
            onSearch(category)
        } label: {
            AppLocalizedLabel(titleKey, systemImage: symbol, locale: locale)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .mapGlassSurface(cornerRadius: 16, glassIntensity: glassIntensity)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
