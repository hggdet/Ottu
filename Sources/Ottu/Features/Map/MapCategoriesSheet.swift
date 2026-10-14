import SwiftUI

struct MapCategoriesSheet: View {
    let locale: Locale
    let onSelectCategory: (String) -> Void
    let onSelectAction: (MapCategoryAction) -> Void
    let onDismiss: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("categories.place_types")
                            .font(.headline)
                            .padding(.horizontal, 2)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(MapPlaceCategory.allCases) { category in
                                Button {
                                    onSelectCategory(String(localized: category.queryResource, locale: locale))
                                } label: {
                                    VStack(spacing: 11) {
                                        Image(systemName: category.symbol)
                                            .font(.system(size: 24, weight: .regular))
                                            .foregroundStyle(.tint)
                                        Text(category.title)
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
                                .accessibilityLabel(Text(category.title))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("categories.map_tools")
                            .font(.headline)
                            .padding(.horizontal, 2)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(MapCategoryAction.allCases) { action in
                                Button {
                                    onSelectAction(action)
                                } label: {
                                    HStack(spacing: 11) {
                                        Image(systemName: action.symbol)
                                            .font(.system(size: 19, weight: .regular))
                                            .foregroundStyle(.tint)
                                            .frame(width: 24)
                                        Text(action.title)
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
                                .accessibilityLabel(Text(action.title))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.primary.opacity(0.025))
            .navigationTitle(Text("navigation.categories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done", action: onDismiss)
                }
            }
        }
    }
}

enum MapCategoryAction: String, CaseIterable, Identifiable {
    case location
    case saved
    case addPlace
    case report
    case offline

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .location: "location.my_location"
        case .saved: "saved.title"
        case .addPlace: "community.add_place"
        case .report: "incident.report"
        case .offline: "offline.download"
        }
    }

    var symbol: String {
        switch self {
        case .location: "location.north"
        case .saved: "bookmark"
        case .addPlace: "plus"
        case .report: "exclamationmark.bubble"
        case .offline: "arrow.down.circle"
        }
    }
}

private enum MapPlaceCategory: String, CaseIterable, Identifiable {
    case restaurants
    case cafes
    case markets
    case pharmacies
    case hospitals
    case fuel
    case parks
    case hotels

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .restaurants: "categories.restaurants"
        case .cafes: "categories.cafes"
        case .markets: "categories.markets"
        case .pharmacies: "categories.pharmacies"
        case .hospitals: "categories.hospitals"
        case .fuel: "categories.fuel"
        case .parks: "categories.parks"
        case .hotels: "categories.hotels"
        }
    }

    var queryResource: LocalizedStringResource {
        switch self {
        case .restaurants: "categories.restaurants"
        case .cafes: "categories.cafes"
        case .markets: "categories.markets"
        case .pharmacies: "categories.pharmacies"
        case .hospitals: "categories.hospitals"
        case .fuel: "categories.fuel"
        case .parks: "categories.parks"
        case .hotels: "categories.hotels"
        }
    }

    var symbol: String {
        switch self {
        case .restaurants: "fork.knife"
        case .cafes: "cup.and.saucer"
        case .markets: "basket"
        case .pharmacies: "cross.case"
        case .hospitals: "cross"
        case .fuel: "fuelpump"
        case .parks: "tree"
        case .hotels: "bed.double"
        }
    }
}
