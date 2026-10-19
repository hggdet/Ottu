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
                mapIconCredit("about.map_icons.location_pin", creator: "Magnific", creatorURL: "https://www.flaticon.com/authors/magnific", iconURL: "https://www.flaticon.com/free-icon/location_2838912")
                mapIconCredit("about.map_icons.ai", creator: "RIkas Dzihab", creatorURL: "https://www.flaticon.com/authors/rikas-dzihab", iconURL: "https://www.flaticon.com/free-icon/ai_17653301")
                mapIconCredit("about.map_icons.settings", creator: "Magnific", creatorURL: "https://www.flaticon.com/authors/magnific", iconURL: "https://www.flaticon.com/free-icon/setting_2040504")
                mapIconCredit("about.map_icons.weather", creator: "Magnific", creatorURL: "https://www.flaticon.com/authors/magnific", iconURL: "https://www.flaticon.com/free-icon/cloudy_2932445")
            } header: {
                AppLocalizedText("about.map_icons_section")
            } footer: {
                AppLocalizedText("about.map_icons_license")
            }
        }
        .navigationTitle(Text(AppLocalization.string("about.title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mapIconCredit(_ roleKey: String, creator: String, creatorURL: String, iconURL: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AppLocalizedText(roleKey)
                .font(.subheadline)

            AppLocalizedText("about.map_icons.made_by")
                .font(.footnote)
            Link(creator, destination: URL(string: creatorURL)!)
                .font(.footnote)

            HStack(spacing: 4) {
                AppLocalizedText("about.map_icons.from")
                Link("Flaticon", destination: URL(string: iconURL)!)
            }
            .font(.footnote)
        }
    }
}
