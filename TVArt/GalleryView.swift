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
    @State private var sort: ArtworkSort = .famous

    private var visible: [Artwork] {
        guard artist != nil else { return settings.favoriteArtworks }
        let base = onlyFavorites ? artworks.filter { settings.favorites.contains($0.id) } : artworks
        return sort.apply(base)
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
                            Label("Start exhibition", systemImage: "play.fill")
                        }
                    }
                    if artist != nil {
                        Menu {
                            Picker("Sort by", selection: $sort) {
                                ForEach(ArtworkSort.allCases) { option in
                                    Label(option.label, systemImage: option.symbol).tag(option)
                                }
                            }
                        } label: {
                            Label(sort.label, systemImage: "arrow.up.arrow.down")
                        }
                        Button { onlyFavorites.toggle() } label: {
                            Label(onlyFavorites ? LocalizedStringKey("All works") : LocalizedStringKey("Favorites only"),
                                  systemImage: onlyFavorites ? "square.grid.2x2" : "heart")
                        }
                    }
                    if !loading || artist == nil {
                        Text("\(visible.count) works")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.headline)

                if loading && artist != nil {
                    VStack(spacing: 24) {
                        ProgressView()
                        Text("Fetching paintings from the museums…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else if visible.isEmpty {
                    emptyState
                } else {
                    ArtworkGrid(artworks: visible, showArtist: artist == nil)
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
            Text(artist == nil ? LocalizedStringKey("No favorites yet. Press ▲ during an exhibition to save an artwork.")
                 : onlyFavorites ? LocalizedStringKey("No favorites for this artist yet.")
                 : LocalizedStringKey("The museum collections can't be reached right now, or no public-domain works were found."))
                .multilineTextAlignment(.center)
            if artist != nil && !onlyFavorites {
                Button("Try again") { Task { await refresh() } }
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

/// How the works of one artist are ordered.
enum ArtworkSort: String, CaseIterable, Identifiable {
    case famous, titleAZ, titleZA, oldest, newest
    var id: String { rawValue }

    var label: String {
        switch self {
        case .famous: return String(localized: "Best known")
        case .titleAZ: return String(localized: "Title A–Z")
        case .titleZA: return String(localized: "Title Z–A")
        case .oldest: return String(localized: "Year: oldest first")
        case .newest: return String(localized: "Year: newest first")
        }
    }

    var symbol: String {
        switch self {
        case .famous: return "star"
        case .titleAZ: return "textformat"
        case .titleZA: return "textformat"
        case .oldest: return "calendar"
        case .newest: return "calendar"
        }
    }

    func apply(_ works: [Artwork]) -> [Artwork] {
        switch self {
        case .famous:
            return works
        case .titleAZ:
            return works.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleZA:
            return works.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        case .oldest, .newest:
            // Works without a known year always go last.
            let dated = works.filter { $0.year != nil }
            let undated = works.filter { $0.year == nil }
            let sorted = dated.sorted { self == .oldest ? $0.year! < $1.year! : $0.year! > $1.year! }
            return sorted + undated
        }
    }
}

extension Artwork {
    /// First four-digit number in the date ("c. 1889", "1888–89" → 1888).
    var year: Int? {
        guard let range = date.range(of: #"\d{4}"#, options: .regularExpression) else { return nil }
        return Int(date[range])
    }
}

/// Grid of artwork cards; selecting one starts an exhibition from that work.
struct ArtworkGrid: View {
    let artworks: [Artwork]
    var showArtist: Bool = false
    @EnvironmentObject var settings: GallerySettings
    private let cols = [GridItem(.adaptive(minimum: 360), spacing: 44)]

    var body: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 50) {
            ForEach(Array(artworks.enumerated()), id: \.element.id) { index, artwork in
                VStack(alignment: .leading, spacing: 14) {
                    NavigationLink {
                        SlideshowView(artworks: artworks, startIndex: index)
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
                    Text(showArtist ? [artwork.artist, artwork.date].filter { !$0.isEmpty }.joined(separator: " · ") : artwork.date)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(width: 360)
            }
        }
    }
}
