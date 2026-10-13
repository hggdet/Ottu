import SwiftUI

struct ReportIncidentView: View {
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
                Section("incident.new") {
                    Picker("incident.type", selection: $kind) {
                        ForEach(IncidentKind.allCases) { item in
                            Label(LocalizedStringKey(item.titleKey), systemImage: item.symbol).tag(item)
                        }
                    }
                    TextField("incident.note_optional", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Section {
                    Text("incident.local_only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        onSave(IncidentReport(kind: kind, note: note, coordinate: coordinate))
                        showSavedMessage = true
                        note = ""
                    } label: {
                        Label("incident.submit", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                if !reports.isEmpty {
                    Section("incident.recent") {
                        ForEach(reports.prefix(8)) { report in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: report.kind.symbol)
                                    .foregroundStyle(.orange)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(LocalizedStringKey(report.kind.titleKey)).font(.subheadline.weight(.medium))
                                    if !report.note.isEmpty {
                                        Text(report.note).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(report.createdAt, style: .relative)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("incident.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onCancel) {
                        Label("common.done", systemImage: "checkmark")
                    }
                }
            }
            .alert("incident.saved_title", isPresented: $showSavedMessage) {
                Button(role: .cancel) { } label: {
                    Label("common.ok", systemImage: "checkmark")
                }
            } message: {
                Text("incident.saved_message")
            }
        }
    }
}
