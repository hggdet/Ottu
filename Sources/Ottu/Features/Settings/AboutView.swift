import SwiftUI

struct AboutView: View {
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("عبدالباسط خضير")
                } label: {
                    AppLocalizedText("about.developer")
                }
            } header: {
                AppLocalizedText("about.application")
            }

            Section {
                Link(destination: URL(string: "https://github.com/microsoft/globalmlbuildingfootprints")!) {
                    Label {
                        AppLocalizedText("about.microsoft_source")
                    } icon: {
                        Image(systemName: "building.2.crop.circle")
                    }
                }
                Link(destination: URL(string: "https://cdla.dev/permissive-2-0/")!) {
                    Label {
                        AppLocalizedText("about.microsoft_license")
                    } icon: {
                        Image(systemName: "doc.text")
                    }
                }
            } header: {
                AppLocalizedText("about.license_section")
            } footer: {
                AppLocalizedText("about.microsoft_status")
            }

            Section {
                AppLocalizedText("about.map_status")
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                AppLocalizedText("about.map_section")
            }

            Section {
                mapIconCredit("about.map_icons.location_pin", creator: "Freepik", creatorURL: "https://www.flaticon.com/authors/freepik")
                mapIconCredit("about.map_icons.ai", creator: "FACH", creatorURL: "https://www.flaticon.com/authors/fach")
                mapIconCredit("about.map_icons.settings", creator: "Phoenix Group", creatorURL: "https://www.flaticon.com/authors/phoenix-group")
                mapIconCredit("about.map_icons.category", creator: "iconsax", creatorURL: "https://www.flaticon.com/authors/iconsax")
            } header: {
                AppLocalizedText("about.map_icons_section")
            } footer: {
                AppLocalizedText("about.map_icons_license")
            }
        }
        .navigationTitle(Text(AppLocalization.string("about.title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mapIconCredit(_ roleKey: String, creator: String, creatorURL: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AppLocalizedText(roleKey)
                .font(.subheadline)

            AppLocalizedText("about.map_icons.made_by")
                .font(.footnote)
            Link(creator, destination: URL(string: creatorURL)!)
                .font(.footnote)

            HStack(spacing: 4) {
                AppLocalizedText("about.map_icons.from")
                Link("Flaticon", destination: URL(string: "https://www.flaticon.com/")!)
            }
            .font(.footnote)
        }
    }
}
