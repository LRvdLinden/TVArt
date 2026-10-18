import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: GallerySettings
    @Environment(\.dismiss) private var dismiss
    @State private var activity = 0
    private let durations: [Int] = [20, 30, 60, 120, 300, 480]

    var body: some View {
        NavigationStack {
            Form {
                Section("Tentoonstelling") {
                    Picker("Tijd per kunstwerk", selection: $settings.duration) {
                        ForEach(durations, id: \.self) { s in
                            Text(s < 60 ? "\(s) seconden" : s == 60 ? "1 minuut" : "\(s / 60) minuten").tag(s)
                        }
                    }
                    Picker("Weergave", selection: $settings.fitModeRaw) {
                        ForEach(FitMode.allCases) { mode in Text(mode.label).tag(mode.rawValue) }
                    }
                    Toggle("Willekeurige volgorde", isOn: $settings.random)
                    Toggle("Langzame zoom (Ken Burns)", isOn: $settings.zoom)
                    Toggle("Museumbordje bij elk werk", isOn: $settings.captions)
                    Toggle("Zwevende klok", isOn: $settings.clock)
                    Toggle("Bedieningstips tonen", isOn: $settings.hints)
                }
                Section("Bediening") {
                    LabeledContent("◀ ▶", value: "Vorige / volgende")
                    LabeledContent("▲", value: "Favoriet aan/uit")
                    LabeledContent("▼ of klik", value: "Museumbordje tonen")
                    LabeledContent("⏯", value: "Pauze / hervat")
                    LabeledContent("Klik ingedrukt houden", value: "Instellingen")
                }
                Section("Over TVArt") {
                    LabeledContent("Versie", value: Theme.appVersion)
                    Text("Werken worden rechtstreeks uit de openbare collecties van het Art Institute of Chicago en The Metropolitan Museum of Art geladen. Alleen werken die de bron als publiek domein markeert worden getoond.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Instellingen")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gereed") { dismiss() } } }
        }
        // Close automatically after a minute without changes, so nothing burns into the screen.
        .onReceive(settings.objectWillChange) { _ in activity += 1 }
        .task(id: activity) {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }
}
