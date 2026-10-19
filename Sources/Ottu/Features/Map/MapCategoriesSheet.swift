import SwiftUI

struct MapCategoriesSheet: View {
    let locale: Locale
    let onSelectCategory: (AssistantPlaceCategory) -> Void
    let onSelectAction: (MapCategoryAction) -> Void
    let onDismiss: () -> Void

    private var columns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    placeTypesSection
                    mapToolsSection
                }
                .padding(20)
            }
            .background(Color.primary.opacity(0.025))
            .navigationTitle(Text(AppLocalization.string("navigation.categories", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        AppLocalizedText("common.done", locale: locale)
                    }
                }
            }
        }
    }

    private var placeTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppLocalizedText("categories.place_types", locale: locale)
                .font(.headline)
                .padding(.horizontal, 2)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MapPlaceCategory.allCases) { category in
                    placeCategoryButton(category)
                }
            }
        }
    }

    private var mapToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppLocalizedText("categories.map_tools", locale: locale)
                .font(.headline)
                .padding(.horizontal, 2)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MapCategoryAction.allCases) { action in
                    mapActionButton(action)
                }
            }
        }
    }

    private func placeCategoryButton(_ category: MapPlaceCategory) -> some View {
        Button {
            onSelectCategory(category.nearbyCategory)
        } label: {
            VStack(spacing: 11) {
                Image(systemName: category.symbol)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.tint)
                AppLocalizedText(category.title, locale: locale)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppLocalization.string(category.title, locale: locale)))
    }

    private func mapActionButton(_ action: MapCategoryAction) -> some View {
        Button {
            onSelectAction(action)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: action.symbol)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                AppLocalizedText(action.title, locale: locale)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppLocalization.string(action.title, locale: locale)))
    }
}

enum MapCategoryAction: String, CaseIterable, Identifiable {
    case saved
    case addPlace
    case report
    case offline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved: "saved.title"
        case .addPlace: "community.add_place"
        case .report: "incident.report"
        case .offline: "offline.download"
        }
    }

    var symbol: String {
        switch self {
        case .saved: "bookmark"
        case .addPlace: "plus"
        case .report: "exclamationmark.bubble"
        case .offline: "arrow.down.circle"
        }
    }
}

private enum MapPlaceCategory: String, CaseIterable, Identifiable {
    case markets
    case hospitals
    case parks
    case hotels

    var id: String { rawValue }

    var title: String {
        nearbyCategory.titleKey
    }

    var symbol: String {
        switch self {
        case .markets: "basket"
        case .hospitals: "cross"
        case .parks: "tree"
        case .hotels: "bed.double"
        }
    }

    var nearbyCategory: AssistantPlaceCategory {
        switch self {
        case .markets: .market
        case .hospitals: .hospital
        case .parks: .park
        case .hotels: .hotel
        }
    }
}
