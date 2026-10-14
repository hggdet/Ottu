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
        }
        .navigationTitle(Text(AppLocalization.string("about.title", locale: locale)))
        .navigationBarTitleDisplayMode(.inline)
    }
}
