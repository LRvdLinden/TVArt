import SwiftUI

/// Settings in the style of the Apple TV Settings app: artwork on the left, a focusable list on the right.
/// Every row is a single click: toggles flip, choices cycle to the next value. Menu closes the screen.
struct SettingsView: View {
    @EnvironmentObject var settings: GallerySettings
    @Environment(\.dismiss) private var dismiss
    @State private var activity = 0

    var body: some View {
        ZStack {
            Image("SplashArt")
                .resizable()
                .scaledToFill()
                .blur(radius: 60)
                .overlay(Color.black.opacity(0.72))
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 80) {
                // Left: brand panel
                VStack(spacing: 34) {
                    Spacer()
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(5.0 / 3.0, contentMode: .fit)
                        .frame(width: 560)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.6), radius: 40, y: 20)
                    Wordmark(size: 72)
                    Text("Version \(Theme.appVersion)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(width: 640)

                // Right: settings list
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Settings")
                            .font(Theme.display(64))
                            .padding(.bottom, 16)

                        SettingsHeader("Exhibition")
                        SettingsRow(title: "Time per artwork", value: GallerySettings.durationLabel(settings.duration)) {
                            settings.cycleDuration()
                        }
                        SettingsRow(title: "Display", value: settings.fitMode.label) { settings.cycleFitMode() }
                        SettingsToggleRow(title: "Shuffle", isOn: $settings.random)
                        SettingsToggleRow(title: "Slow zoom (Ken Burns)", isOn: $settings.zoom)
                        SettingsToggleRow(title: "Museum label on each artwork", isOn: $settings.captions)
                        SettingsToggleRow(title: "Floating clock", isOn: $settings.clock)
                        SettingsToggleRow(title: "Show remote tips", isOn: $settings.hints)

                        SettingsHeader("Music")
                        SettingsToggleRow(title: "Classical music in the background", isOn: $settings.music)
                        SettingsRow(title: "Volume", value: settings.musicLevelLabel) { settings.cycleMusicLevel() }
                        Text("Debussy – Clair de lune · Satie – Gymnopédie No. 1 (Michael Laucke) · Chopin – Nocturne Op. 9 No. 2 (Frank Lévy). Public-domain recordings via Wikimedia Commons, played one after another on a loop.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)

                        SettingsHeader("Screensaver")
                        SettingsRow(title: "Start automatically", value: GallerySettings.delayLabel(settings.screensaverDelay)) {
                            settings.cycleScreensaverDelay()
                        }
                        SettingsRow(title: "Theme", value: settings.screensaverTheme.title) { settings.cycleScreensaverTheme() }
                        Text("While TVArt shows art, the Apple TV screensaver stays off, so artworks can stay on screen for hours.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)

                        SettingsHeader("Siri Remote")
                        SettingsInfoRow(title: "◀ ▶", value: String(localized: "Previous / next"))
                        SettingsInfoRow(title: "▲", value: String(localized: "Favorite on/off"))
                        SettingsInfoRow(title: "▼ / click", value: String(localized: "Show museum label"))
                        SettingsInfoRow(title: "⏯", value: String(localized: "Pause / resume"))
                        SettingsInfoRow(title: "Hold click", value: String(localized: "Settings"))

                        SettingsHeader("About TVArt")
                        Text("Artworks and titles come from Wikidata and Wikimedia Commons, supplemented by the open-access collections of The Metropolitan Museum of Art and the Cleveland Museum of Art. Only public-domain works are shown. These settings are also available in the Apple TV Settings app.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                            .focusable()   // lets the list scroll all the way down with the remote
                    }
                    .padding(.vertical, 60)
                    .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 90)
        }
        .onExitCommand { dismiss() }
        // Close automatically after a minute without changes, so nothing burns into the screen.
        .onReceive(settings.objectWillChange) { _ in activity += 1 }
        .task(id: activity) {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }
}

private struct SettingsHeader: View {
    let title: LocalizedStringKey
    init(_ title: LocalizedStringKey) { self.title = title }
    var body: some View {
        Text(title)
            .font(.headline)
            .textCase(.uppercase)
            .foregroundStyle(Theme.goldSolid)
            .padding(.top, 30)
            .padding(.leading, 24)
    }
}

/// A full-width row that looks like the rows in tvOS Settings: white when focused.
private struct SettingsRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration)
    }
    private struct RowBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var focused
        var body: some View {
            configuration.label
                .font(.title3)
                .foregroundStyle(focused ? Color.black : Color.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(focused ? Color.white : Color.white.opacity(0.08))
                )
                .scaleEffect(focused ? 1.03 : 1)
                .shadow(color: .black.opacity(focused ? 0.45 : 0), radius: 18, y: 10)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(.easeOut(duration: 0.18), value: focused)
        }
    }
}

private struct SettingsRow: View {
    let title: LocalizedStringKey
    let value: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(value).opacity(0.65)
                Image(systemName: "chevron.up.chevron.down").font(.callout).opacity(0.5)
            }
        }
        .buttonStyle(SettingsRowStyle())
    }
}

private struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack {
                Text(title)
                Spacer()
                Text(isOn ? LocalizedStringKey("On") : LocalizedStringKey("Off")).opacity(0.65)
            }
        }
        .buttonStyle(SettingsRowStyle())
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.title3)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }
}
