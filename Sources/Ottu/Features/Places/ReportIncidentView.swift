import SwiftUI

struct ReportIncidentView: View {
    @Environment(\.locale) private var locale
    let coordinate: GeoCoordinate
    let reports: [IncidentReport]
    let onSave: (IncidentReport) -> Void
    let onCancel: () -> Void

    @State private var kind: IncidentKind = .traffic
    @State private var note = ""
    @State private var showSavedMessage = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $kind) {
                        ForEach(IncidentKind.allCases) { item in
                            AppLocalizedLabel(item.titleKey, systemImage: item.symbol).tag(item)
                        }
                    } label: {
                        AppLocalizedText("incident.type")
                    }
                    TextField(AppLocalization.string("incident.note_optional", locale: locale), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                } header: {
                    AppLocalizedText("incident.new")
                }
                Section {
                    AppLocalizedText("incident.local_only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        onSave(IncidentReport(kind: kind, note: note, coordinate: coordinate))
                        showSavedMessage = true
                        note = ""
                    } label: {
                        AppLocalizedLabel("incident.submit", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                if !reports.isEmpty {
                    Section {
                        ForEach(reports.prefix(8)) { report in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: report.kind.symbol)
                                    .foregroundStyle(.orange)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    AppLocalizedText(report.kind.titleKey).font(.subheadline.weight(.medium))
                                    if !report.note.isEmpty {
                                        Text(report.note).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(report.createdAt, style: .relative)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    } header: {
                        AppLocalizedText("incident.recent")
                    }
                }
            }
            .navigationTitle(Text(AppLocalization.string("incident.title", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onCancel) {
                        AppLocalizedLabel("common.done", systemImage: "checkmark")
                    }
                }
            }
            .alert(Text(AppLocalization.string("incident.saved_title", locale: locale)), isPresented: $showSavedMessage) {
                Button(role: .cancel) { } label: {
                    AppLocalizedLabel("common.ok", systemImage: "checkmark")
                }
            } message: {
                AppLocalizedText("incident.saved_message")
            }
        }
    }
}
