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
    @State private var showSplash = true

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
        // Warm up the artist covers while the splash plays.
        .task { await MuseumService.shared.prefetchCovers(for: Artist.collection) }
    }
}
