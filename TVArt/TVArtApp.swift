import SwiftUI

@main
struct TVArtApp: App {
    @StateObject private var settings = GallerySettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}

/// Shows the animated splash first, then fades into the museum home.
struct RootView: View {
    @EnvironmentObject var settings: GallerySettings
    @State private var showSplash = true
    @State private var autoScreensaver = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            ArtistHomeView()
                .opacity(showSplash ? 0 : 1)
                .scaleEffect(showSplash ? 1.03 : 1)
                .disabled(showSplash)

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.9)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        // Soft classical music (3 pieces on a loop), following the settings.
        .onAppear { BackgroundMusic.shared.update(enabled: settings.music, volume: settings.musicVolume) }
        .onChange(of: settings.music) { _, on in BackgroundMusic.shared.update(enabled: on, volume: settings.musicVolume) }
        .onChange(of: settings.musicLevel) { _, _ in BackgroundMusic.shared.update(enabled: settings.music, volume: settings.musicVolume) }
        .onChange(of: scenePhase) { _, phase in BackgroundMusic.shared.appBecameActive(phase == .active) }
        // Warm up all collections in the background (disk-cached for a week).
        .task { await MuseumService.shared.prefetchCovers(for: Artist.collection) }
        // Start the chosen screensaver after the set time without remote input.
        .task {
            try? await Task.sleep(for: .seconds(2))
            ActivityMonitor.shared.install()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                let monitor = ActivityMonitor.shared
                monitor.install()
                guard settings.screensaverDelay > 0, !showSplash, !autoScreensaver,
                      !monitor.exhibitionActive,
                      monitor.idleSeconds >= Double(settings.screensaverDelay * 60) else { continue }
                autoScreensaver = true
            }
        }
        .fullScreenCover(isPresented: $autoScreensaver, onDismiss: { ActivityMonitor.shared.poke() }) {
            ScreensaverView(theme: settings.screensaverTheme)
        }
        // If the cover could not appear (another full-screen view was open), try again later.
        .onChange(of: autoScreensaver) { _, isOn in
            guard isOn else { return }
            Task {
                try? await Task.sleep(for: .seconds(3))
                if !ActivityMonitor.shared.exhibitionActive { autoScreensaver = false; ActivityMonitor.shared.poke() }
            }
        }
    }
}
