import SwiftUI

struct ArtistHomeView: View {
    @EnvironmentObject var settings: GallerySettings
    @State private var showingSettings = false
    @State private var screensaver: ScreensaverTheme?
    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 44)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 36) {
                        sectionTitle("Screensavers")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 44) {
                                ForEach(ScreensaverTheme.allCases.filter { $0 != .favorites || !settings.favoriteArtworks.isEmpty }) { theme in
                                    Button { screensaver = theme } label: { ScreensaverCard(theme: theme) }
                                        .buttonStyle(.card)
                                }
                            }
                            .padding(.vertical, 30)
                        }
                        .padding(.horizontal, -80)
                        .contentMargins(.horizontal, 80, for: .scrollContent)

                        if !settings.favoriteArtworks.isEmpty {
                            sectionTitle("My favorites")
                            NavigationLink {
                                ArtworkCollectionView(title: String(localized: "My favorites"), subtitle: String(localized: "Saved on this Apple TV"), artist: nil)
                            } label: {
                                FavoritesBanner(artworks: settings.favoriteArtworks)
                            }
                            .buttonStyle(.card)
                        }
                        sectionTitle("Choose an artist or collection")
                        LazyVGrid(columns: columns, spacing: 56) {
                            ForEach(Artist.collection) { artist in
                                NavigationLink(value: artist) { ArtistCard(artist: artist) }
                                    .buttonStyle(.card)
                            }
                        }
                        Text("Artworks come from Wikidata and Wikimedia Commons, The Metropolitan Museum of Art and the Cleveland Museum of Art. Internet connection required.")
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
            .fullScreenCover(isPresented: $showingSettings) { SettingsView() }
            .fullScreenCover(item: $screensaver) { theme in ScreensaverView(theme: theme) }
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
                    Text("Your museum. On the biggest screen.")
                        .font(Theme.displayMedium(38))
                        .foregroundStyle(Theme.paper.opacity(0.9))
                }
                Spacer()
                HStack(spacing: 24) {
                    NavigationLink { SearchView() } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
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
                    Text("COLLECTION").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Theme.goldSolid)
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
                    Text("My favorites").font(Theme.display(48))
                    Text("\(artworks.count) artworks").foregroundStyle(.secondary)
                }
            }
            .padding(36)
        }
        .frame(width: 1650, height: 260)
        .clipped()
    }
}
