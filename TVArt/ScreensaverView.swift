import SwiftUI

/// Full-screen screensaver: a shuffled, endless exhibition of a theme across all masters.
struct ScreensaverView: View {
    let theme: ScreensaverTheme
    @EnvironmentObject var settings: GallerySettings
    @Environment(\.dismiss) private var dismiss
    @State private var artworks: [Artwork] = []
    @State private var loading = true

    var body: some View {
        ZStack {
            if !artworks.isEmpty {
                SlideshowView(artworks: artworks, startIndex: 0)
            } else {
                Image("SplashArt")
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .overlay(Color.black.opacity(0.6))
                    .ignoresSafeArea()
                VStack(spacing: 28) {
                    Wordmark(size: 96)
                    Text(theme.title).font(Theme.display(54))
                    if loading {
                        ProgressView()
                        Text("Collecting masterpieces from all masters. The first time takes a moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No artworks found for this screensaver yet.")
                        Text("Press Menu to close.").foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(80)
                .focusable()
                .onExitCommand { dismiss() }
            }
        }
        .task { await load() }
        .onDisappear {
            ActivityMonitor.shared.exhibitionActive = false
            ActivityMonitor.shared.poke()
        }
    }

    private func load() async {
        ActivityMonitor.shared.exhibitionActive = true
        let pool: [Artwork]
        if theme == .favorites {
            pool = settings.favoriteArtworks
        } else {
            pool = await MuseumService.shared.screensaverArtworks(theme: theme)
        }
        guard !Task.isCancelled else { return }
        artworks = pool.shuffled()
        loading = false
    }
}

/// Screensaver tile for the home screen.
struct ScreensaverCard: View {
    let theme: ScreensaverTheme
    @EnvironmentObject var settings: GallerySettings
    @State private var cover: URL?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if theme == .favorites, let fav = settings.favoriteArtworks.first {
                ArtImage(url: fav.thumbnailURL)
            } else if let cover {
                ArtImage(url: cover)
            } else {
                Theme.hall
                Image(systemName: theme.symbol)
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(Theme.goldSolid.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 10) {
                Image(systemName: theme.symbol).foregroundStyle(Theme.goldSolid)
                Text(theme.title).font(Theme.display(34)).foregroundStyle(.white).lineLimit(1)
            }
            .padding(18)
        }
        .frame(width: 420, height: 236)
        .clipped()
        .task(id: theme.id) {
            // Covers appear as soon as the background loading has fetched a matching work.
            for _ in 0..<12 {
                if let url = await MuseumService.shared.themeCover(theme) { cover = url; return }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}
