import Foundation

private struct AICResponse: Decodable {
    struct Entry: Decodable {
        let id: Int
        let title: String
        let artist_title: String?
        let date_display: String?
        let image_id: String?
        let is_public_domain: Bool?
    }
    struct Config: Decodable { let iiif_url: String? }
    let data: [Entry]
    let config: Config?
}
private struct MetSearch: Decodable { let objectIDs: [Int]? }
private struct MetObject: Decodable {
    let objectID: Int
    let title: String
    let artistDisplayName: String?
    let objectDate: String?
    let primaryImage: String?
    let primaryImageSmall: String?
    let isPublicDomain: Bool?
    let objectURL: String?
}

/// Loads public-domain artworks from the Art Institute of Chicago and The Met.
actor MuseumService {
    static let shared = MuseumService()

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 18
        c.requestCachePolicy = .returnCacheDataElseLoad
        c.urlCache = URLCache(memoryCapacity: 30_000_000, diskCapacity: 300_000_000)
        c.httpAdditionalHeaders = ["AIC-User-Agent": "TVArt (nl.lrvdlinden.tvart)"]
        return URLSession(configuration: c)
    }()
    private var cache: [String: [Artwork]] = [:]
    private var covers: [String: URL] = [:]
    private var inFlight: [String: Task<[Artwork], Never>] = [:]

    func load(_ artist: Artist) async -> [Artwork] {
        if let saved = cache[artist.id], !saved.isEmpty { return saved }
        if let running = inFlight[artist.id] { return await running.value }
        let task = Task { await self.fetch(artist) }
        inFlight[artist.id] = task
        let result = await task.value
        inFlight[artist.id] = nil
        if !result.isEmpty { cache[artist.id] = result }
        return result
    }

    /// A representative thumbnail for the home screen (cheap: one Chicago request).
    func cover(for artist: Artist) async -> URL? {
        if let url = covers[artist.id] { return url }
        if let first = cache[artist.id]?.first { covers[artist.id] = first.thumbnailURL; return first.thumbnailURL }
        let found = await chicagoArt(term: artist.terms[0], limit: 12).first?.thumbnailURL
        if let found { covers[artist.id] = found }
        return found
    }

    func prefetchCovers(for artists: [Artist]) async {
        await withTaskGroup(of: Void.self) { group in
            for artist in artists.prefix(8) { group.addTask { _ = await self.cover(for: artist) } }
        }
    }

    private func fetch(_ artist: Artist) async -> [Artwork] {
        var combined: [Artwork] = []
        for term in artist.terms {
            if Task.isCancelled { break }
            async let chicago = chicagoArt(term: term, limit: 100)
            async let met = metropolitanArt(term: term)
            let (a, m) = await (chicago, met)
            combined += a + m
        }
        var seen = Set<String>()
        let unique = combined.filter { seen.insert($0.id).inserted }
        return unique.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func chicagoArt(term: String, limit: Int) async -> [Artwork] {
        var components = URLComponents(string: "https://api.artic.edu/api/v1/artworks/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "query[term][is_public_domain]", value: "true"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "fields", value: "id,title,artist_title,date_display,image_id,is_public_domain")
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(AICResponse.self, from: data) else { return [] }
        let base = payload.config?.iiif_url ?? "https://www.artic.edu/iiif/2"
        return payload.data.compactMap { item in
            guard item.is_public_domain == true, let key = item.image_id,
                  let by = item.artist_title, Self.matches(by, search: term),
                  let image = URL(string: "\(base)/\(key)/full/1686,/0/default.jpg"),
                  let thumb = URL(string: "\(base)/\(key)/full/600,/0/default.jpg") else { return nil }
            return Artwork(id: "aic-\(item.id)", title: item.title, artist: by,
                           date: item.date_display ?? "", imageURL: image, thumbnailURL: thumb,
                           source: "Art Institute of Chicago",
                           detailURL: URL(string: "https://www.artic.edu/artworks/\(item.id)"))
        }
    }

    private func metropolitanArt(term: String) async -> [Artwork] {
        var components = URLComponents(string: "https://collectionapi.metmuseum.org/public/collection/v1/search")!
        components.queryItems = [URLQueryItem(name: "hasImages", value: "true"),
                                 URLQueryItem(name: "artistOrCulture", value: "true"),
                                 URLQueryItem(name: "q", value: term)]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let ids = try? JSONDecoder().decode(MetSearch.self, from: data).objectIDs else { return [] }

        // Fetch object details in small parallel batches to keep the public API and the TV happy.
        let wanted = Array(ids.prefix(30))
        var output: [Artwork] = []
        for batch in stride(from: 0, to: wanted.count, by: 6).map({ Array(wanted[$0..<min($0 + 6, wanted.count)]) }) {
            if Task.isCancelled { break }
            let results = await withTaskGroup(of: Artwork?.self) { group -> [Artwork] in
                for id in batch { group.addTask { await self.metObject(id: id, term: term) } }
                var items: [Artwork] = []
                for await item in group { if let item { items.append(item) } }
                return items
            }
            output += results
        }
        return output
    }

    private func metObject(id: Int, term: String) async -> Artwork? {
        guard let url = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1/objects/\(id)"),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let item = try? JSONDecoder().decode(MetObject.self, from: data),
              item.isPublicDomain == true,
              let artist = item.artistDisplayName, Self.matches(artist, search: term),
              let imageString = item.primaryImage, !imageString.isEmpty,
              let image = URL(string: imageString) else { return nil }
        let thumb = URL(string: item.primaryImageSmall ?? "") ?? image
        return Artwork(id: "met-\(item.objectID)", title: item.title, artist: artist,
                       date: item.objectDate ?? "", imageURL: image, thumbnailURL: thumb,
                       source: "The Metropolitan Museum of Art", detailURL: URL(string: item.objectURL ?? ""))
    }

    private static func matches(_ artist: String, search: String) -> Bool {
        let a = artist.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let b = search.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.contains(b) || b.contains(a)
    }
}
