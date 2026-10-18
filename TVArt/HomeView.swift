import SwiftUI

struct ArtistHomeView: View {
    @EnvironmentObject var settings: GallerySettings
    @State private var showingSettings = false
    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 44)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 36) {
                        if !settings.favoriteArtworks.isEmpty {
                            sectionTitle("Mijn favorieten")
                            NavigationLink {
                                ArtworkCollectionView(title: "Mijn favorieten", subtitle: "Bewaard op deze Apple TV", artist: nil)
                            } label: {
                                FavoritesBanner(artworks: settings.favoriteArtworks)
                            }
                            .buttonStyle(.card)
                        }
                        sectionTitle("Kies een kunstenaar of collectie")
                        LazyVGrid(columns: columns, spacing: 56) {
                            ForEach(Artist.collection) { artist in
                                NavigationLink(value: artist) { ArtistCard(artist: artist) }
                                    .buttonStyle(.card)
                            }
                        }
                        Text("Kunstwerken worden live geladen uit de openbare collecties van het Art Institute of Chicago en The Metropolitan Museum of Art. Internetverbinding vereist.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                    }
                    .padding(.horizontal, 80)
                    .padding(.bottom, 80)
                }
            }
            .background(Theme.ink.ignoresSafeArea())
            .navigationDestination(for: Artist.self) { artist in
                ArtworkCollectionView(title: artist.name, subtitle: artist.years, artist: artist)
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
        .tint(Theme.goldSolid)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 560)
                .overlay(Image("SplashArt").resizable().scaledToFill())
                .clipped()
                .overlay(LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.15), .clear],
                                        startPoint: .leading, endPoint: .trailing))
                .overlay(LinearGradient(colors: [.clear, Theme.ink], startPoint: .center, endPoint: .bottom))
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Wordmark(size: 120)
                    Text("Jouw museum. Op het grootste scherm.")
                        .font(Theme.displayMedium(38))
                        .foregroundStyle(Theme.paper.opacity(0.9))
                }
                Spacer()
                Button { showingSettings = true } label: {
                    Label("Instellingen", systemImage: "gearshape")
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(Theme.display(46)).foregroundStyle(Theme.paper)
    }
}

struct ArtistCard: View {
    let artist: Artist
    @State private var cover: URL?
    @State private var loaded = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if cover != nil || !loaded {
                    ArtImage(url: cover, contentMode: .fill)
                } else {
                    ZStack {
                        Theme.hall
                        Image(systemName: artist.symbol)
                            .font(.system(size: 90, weight: .ultraLight))
                            .foregroundStyle(Theme.goldSolid.opacity(0.8))
                    }
                }
            }
            .frame(width: 400, height: 250)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 2) {
                if artist.isCollection {
                    Text("COLLECTIE").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Theme.goldSolid)
                }
                Text(artist.name).font(Theme.display(36)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                Text(artist.years).font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            .padding(20)
        }
        .frame(width: 400, height: 250)
        .task(id: artist.id) {
            cover = await MuseumService.shared.cover(for: artist)
            loaded = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artist.name), \(artist.years)")
    }
}

struct FavoritesBanner: View {
    let artworks: [Artwork]
    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(artworks.prefix(5)) { art in
                    ArtImage(url: art.thumbnailURL).frame(width: 330, height: 260).clipped()
                }
                Spacer(minLength: 0)
            }
            LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
            HStack(spacing: 20) {
                Image(systemName: "heart.fill").font(.system(size: 44)).foregroundStyle(Theme.goldSolid)
                VStack(alignment: .leading) {
                    Text("Mijn favorieten").font(Theme.display(48))
                    Text("\(artworks.count) \(artworks.count == 1 ? "kunstwerk" : "kunstwerken")").foregroundStyle(.secondary)
                }
            }
            .padding(36)
        }
        .frame(width: 1650, height: 260)
        .clipped()
    }
}
