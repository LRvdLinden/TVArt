import SwiftUI

/// Search across all masters: artist names and painting titles.
struct SearchView: View {
    @State private var query = ""
    @State private var results: [Artwork] = []
    @State private var searching = false
    private let artistColumns = [GridItem(.adaptive(minimum: 400), spacing: 44)]

    private var artists: [Artist] {
        let q = Self.fold(query)
        guard q.count >= 2 else { return [] }
        return Artist.collection.filter { Self.fold($0.name).contains(q) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    VStack(spacing: 18) {
                        Image(systemName: "magnifyingglass").font(.system(size: 70, weight: .ultraLight)).foregroundStyle(Theme.goldSolid)
                        Text("Search by artist or painting, for example “Van Gogh”, “Sterrennacht” or “Mona Lisa”.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .font(.title3)
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    if !artists.isEmpty {
                        Text("Artists").font(Theme.display(46))
                        LazyVGrid(columns: artistColumns, alignment: .leading, spacing: 56) {
                            ForEach(artists) { artist in
                                NavigationLink(value: artist) { ArtistCard(artist: artist) }
                                    .buttonStyle(.card)
                            }
                        }
                    }
                    HStack(spacing: 20) {
                        Text("Paintings").font(Theme.display(46))
                        if searching { ProgressView() } else { Text("\(results.count) works").foregroundStyle(.secondary) }
                    }
                    if results.isEmpty && !searching {
                        Text("No paintings found.").foregroundStyle(.secondary)
                    } else {
                        ArtworkGrid(artworks: results, showArtist: true)
                    }
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
        .background(Theme.ink.ignoresSafeArea())
        .searchable(text: $query, prompt: Text("Artist or painting"))
        .task(id: query) {
            let q = query
            guard q.trimmingCharacters(in: .whitespaces).count >= 2 else { results = []; return }
            searching = true
            try? await Task.sleep(for: .milliseconds(350))   // wait until typing pauses
            guard !Task.isCancelled else { return }
            let found = await MuseumService.shared.search(q)
            guard !Task.isCancelled else { return }
            results = found
            searching = false
        }
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .trimmingCharacters(in: .whitespaces)
    }
}
