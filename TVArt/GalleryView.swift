import SwiftUI

/// Grid of artworks for an artist, or the user's favorites when `artist` is nil.
struct ArtworkCollectionView: View {
    let title: String
    let subtitle: String
    let artist: Artist?

    @EnvironmentObject var settings: GallerySettings
    @State private var artworks: [Artwork] = []
    @State private var loading = true
    @State private var onlyFavorites = false
    private let cols = [GridItem(.adaptive(minimum: 360), spacing: 44)]

    private var visible: [Artwork] {
        guard artist != nil else { return settings.favoriteArtworks }
        return onlyFavorites ? artworks.filter { settings.favorites.contains($0.id) } : artworks
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(Theme.display(76)).foregroundStyle(Theme.paper)
                    Text(subtitle).font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 28) {
                    if !visible.isEmpty {
                        NavigationLink {
                            SlideshowView(artworks: visible, startIndex: 0)
                        } label: {
                            Label("Start tentoonstelling", systemImage: "play.fill")
                        }
                    }
                    if artist != nil {
                        Button { onlyFavorites.toggle() } label: {
                            Label(onlyFavorites ? "Alle werken" : "Alleen favorieten",
                                  systemImage: onlyFavorites ? "square.grid.2x2" : "heart")
                        }
                    }
                    if !loading || artist == nil {
                        Text("\(visible.count) \(visible.count == 1 ? "werk" : "werken")")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.headline)

                if loading && artist != nil {
                    VStack(spacing: 24) {
                        ProgressView()
                        Text("Schilderijen ophalen bij de musea…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else if visible.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: cols, alignment: .leading, spacing: 50) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, artwork in
                            VStack(alignment: .leading, spacing: 14) {
                                NavigationLink {
                                    SlideshowView(artworks: visible, startIndex: index)
                                } label: {
                                    ArtImage(url: artwork.thumbnailURL)
                                        .frame(width: 360, height: 230)
                                        .clipped()
                                        .overlay(alignment: .topTrailing) {
                                            if settings.favorites.contains(artwork.id) {
                                                Image(systemName: "heart.fill")
                                                    .foregroundStyle(Theme.goldSolid)
                                                    .padding(12)
                                                    .shadow(radius: 6)
                                            }
                                        }
                                }
                                .buttonStyle(.card)
                                Text(artwork.title).font(.callout.weight(.semibold)).lineLimit(2)
                                Text(artist == nil ? artwork.artist : artwork.date)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(width: 360)
                        }
                    }
                }
            }
            .padding(80)
        }
        .background(Theme.ink.ignoresSafeArea())
        .task(id: artist?.id) { await refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image(systemName: "photo.artframe").font(.system(size: 80, weight: .ultraLight)).foregroundStyle(Theme.goldSolid)
            Text(artist == nil ? "Nog geen favorieten. Druk tijdens een tentoonstelling op ▲ om een werk te bewaren."
                 : onlyFavorites ? "Nog geen favorieten voor deze kunstenaar."
                 : "De museumcollecties zijn nu niet bereikbaar, of er zijn geen rechtenvrije werken gevonden.")
                .multilineTextAlignment(.center)
            if artist != nil && !onlyFavorites {
                Button("Opnieuw proberen") { Task { await refresh() } }
            }
        }
        .font(.title3)
        .frame(maxWidth: .infinity, minHeight: 380)
    }

    private func refresh() async {
        guard let artist else { loading = false; return }
        loading = true
        let data = await MuseumService.shared.load(artist)
        guard !Task.isCancelled else { return }
        artworks = data
        loading = false
        await ImagePipeline.shared.prefetch(Array(data.prefix(12).map(\.thumbnailURL)))
    }
}
