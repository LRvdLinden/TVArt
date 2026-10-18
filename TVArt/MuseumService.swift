import Foundation

// MARK: - The Met (Collection API v1.1 search + v1 objects)

private struct MetSearch: Decodable { let total: Int?; let objectIDs: [Int]? }
private struct MetObject: Decodable {
    let objectID: Int
    let title: String?
    let artistDisplayName: String?
    let objectDate: String?
    let primaryImage: String?
    let primaryImageSmall: String?
    let isPublicDomain: Bool?
    let objectURL: String?
    let classification: String?
}

// MARK: - Wikidata (SPARQL) + Wikimedia Commons images

private struct SPARQLResponse: Decodable {
    struct Value: Decodable { let value: String }
    struct Results: Decodable { let bindings: [[String: Value]] }
    let results: Results
}

// MARK: - Cleveland Museum of Art (Open Access API, CC0)

private struct CMAResponse: Decodable {
    struct Item: Decodable {
        struct Creator: Decodable { let description: String? }
        struct Images: Decodable {
            struct Image: Decodable { let url: String? }
            let web: Image?
            let print: Image?
        }
        let id: Int
        let title: String?
        let creation_date: String?
        let creators: [Creator]?
        let images: Images?
        let type: String?
        let url: String?
    }
    let data: [Item]
}

/// Loads public-domain artworks from The Metropolitan Museum of Art and the Cleveland Museum of Art.
/// (The Art Institute of Chicago was dropped: its image server now blocks apps with a bot challenge.)
actor MuseumService {
    static let shared = MuseumService()

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        c.requestCachePolicy = .returnCacheDataElseLoad
        c.urlCache = URLCache(memoryCapacity: 30_000_000, diskCapacity: 300_000_000)
        c.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: c)
    }()
    private var cache: [String: [Artwork]] = [:]
    private var covers: [String: URL] = [:]
    private var inFlight: [String: Task<[Artwork], Never>] = [:]
    /// The Met sits behind bot protection that answers bursts with HTTP 403. After the first 403
    /// we stop calling it for this session and rely on Cleveland + the disk cache.
    private var metBlocked = false

    private struct DiskEntry: Codable { let date: Date; let artworks: [Artwork] }
    private let diskDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("TVArtCollections.v2", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Titles come in the device language, so the cache is per language.
    private static var language: String {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("nl") ? "nl" : "en"
    }

    private func readDisk(_ id: String) -> [Artwork]? {
        guard let data = try? Data(contentsOf: diskDir.appendingPathComponent("\(id)-\(Self.language).json")),
              let entry = try? JSONDecoder().decode(DiskEntry.self, from: data),
              Date().timeIntervalSince(entry.date) < 7 * 24 * 3600, !entry.artworks.isEmpty else { return nil }
        return entry.artworks
    }

    private func writeDisk(_ id: String, _ artworks: [Artwork]) {
        guard let data = try? JSONEncoder().encode(DiskEntry(date: Date(), artworks: artworks)) else { return }
        try? data.write(to: diskDir.appendingPathComponent("\(id)-\(Self.language).json"), options: .atomic)
    }

    func load(_ artist: Artist) async -> [Artwork] {
        if let saved = cache[artist.id], !saved.isEmpty { return saved }
        if let disk = readDisk(artist.id) { cache[artist.id] = disk; return disk }
        if let running = inFlight[artist.id] { return await running.value }
        let task = Task { await self.fetch(artist) }
        inFlight[artist.id] = task
        let result = await task.value
        inFlight[artist.id] = nil
        if !result.isEmpty {
            cache[artist.id] = result
            writeDisk(artist.id, result)
        }
        return result
    }

    /// The most famous work of the artist, used as the cover on the home screen.
    func cover(for artist: Artist) async -> URL? {
        if let url = covers[artist.id] { return url }
        let found = await load(artist).first?.thumbnailURL
        if let found { covers[artist.id] = found }
        return found
    }

    /// Loads every collection once in the background (disk-cached for a week) so covers and
    /// screensavers are ready. Wikidata queries are throttled by `wikidataSlot()`.
    func prefetchCovers(for artists: [Artist]) async {
        for artist in artists {
            if Task.isCancelled { return }
            _ = await cover(for: artist)
        }
    }

    /// Mix of the best-known works of all masters, for screensavers.
    func screensaverArtworks(theme: ScreensaverTheme, perArtist: Int = 120) async -> [Artwork] {
        let artists = Artist.collection.filter { $0.id != "botticelli" }   // already inside Renaissance
        let lists = await withTaskGroup(of: [Artwork].self) { group -> [[Artwork]] in
            for artist in artists { group.addTask { await self.load(artist) } }
            var all: [[Artwork]] = []
            for await list in group { all.append(list) }
            return all
        }
        return lists.flatMap { Self.filter($0, theme: theme).prefix(perArtist) }
    }

    /// Finds paintings whose title or maker contains the query, across all collections
    /// (most famous first). Collections that are not cached yet are loaded on the way.
    func search(_ query: String, limit: Int = 300) async -> [Artwork] {
        let words = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        var hits: [Artwork] = []
        var seen = Set<String>()
        for artist in Artist.collection {
            if Task.isCancelled { return [] }
            for art in await load(artist) where !seen.contains(art.id) {
                let haystack = (art.title + " " + art.artist + " " + artist.name)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
                if words.allSatisfy({ haystack.contains($0) }) {
                    seen.insert(art.id)
                    hits.append(art)
                }
            }
        }
        // Title matches before matches on the artist name only; then by fame.
        let titleWords = words
        func titleHit(_ a: Artwork) -> Bool {
            let t = a.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            return titleWords.contains { t.contains($0) }
        }
        let sorted = hits.enumerated().sorted { lhs, rhs in
            let l = titleHit(lhs.element), r = titleHit(rhs.element)
            if l != r { return l }
            let lp = lhs.element.popularity ?? 0, rp = rhs.element.popularity ?? 0
            if lp != rp { return lp > rp }
            return lhs.offset < rhs.offset
        }.map(\.element)
        return Array(sorted.prefix(limit))
    }

    /// Cover for a screensaver theme, using only collections that are already loaded (no network).
    func themeCover(_ theme: ScreensaverTheme) -> URL? {
        for artist in Artist.collection {
            if cache[artist.id] == nil, let disk = readDisk(artist.id) { cache[artist.id] = disk }
            if let hit = Self.filter(cache[artist.id] ?? [], theme: theme).first { return hit.thumbnailURL }
        }
        return nil
    }

    private static func filter(_ works: [Artwork], theme: ScreensaverTheme) -> [Artwork] {
        guard let genres = theme.genres else { return works }
        return works.filter { !Set($0.genres ?? []).isDisjoint(with: genres) }
    }

    // MARK: Wikidata throttle (max 2 queries at a time, as the query service asks)

    private var wikidataRunning = 0
    private var wikidataWaiters: [CheckedContinuation<Void, Never>] = []

    private func wikidataSlot() async {
        if wikidataRunning < 2 { wikidataRunning += 1; return }
        await withCheckedContinuation { wikidataWaiters.append($0) }
    }

    private func releaseWikidataSlot() {
        if wikidataWaiters.isEmpty { wikidataRunning -= 1 } else { wikidataWaiters.removeFirst().resume() }
    }

    private func fetch(_ artist: Artist) async -> [Artwork] {
        // 1. Wikidata + Wikimedia Commons: hundreds of works per master, ordered by fame.
        let wiki = await wikidata(artist)
        if wiki.count >= 12 { return wiki }
        // 2. Fallback / supplement: The Met and the Cleveland Museum of Art.
        let legacy = await museums(artist)
        var seen = Set(wiki.map(\.id))
        return wiki + legacy.filter { seen.insert($0.id).inserted }
    }

    private func wikidata(_ artist: Artist) async -> [Artwork] {
        let creators = artist.wikidataIDs.map { "wd:\($0)" }.joined(separator: " ")
        guard !creators.isEmpty else { return [] }
        let lang = Self.language == "nl" ? "nl,en" : "en,nl"
        let query = """
        SELECT ?item ?itemLabel ?image ?year ?creatorLabel ?collectionLabel ?links ?genre WHERE {
          VALUES ?creator { \(creators) }
          VALUES ?type { wd:Q3305213 wd:Q18218093 }
          ?item wdt:P170 ?creator; wdt:P31 ?type; wdt:P18 ?image; wikibase:sitelinks ?links.
          OPTIONAL { ?item wdt:P571 ?inception. BIND(YEAR(?inception) AS ?year) }
          OPTIONAL { ?item wdt:P195 ?collection }
          OPTIONAL { ?item wdt:P136 ?genre }
          SERVICE wikibase:label { bd:serviceParam wikibase:language "\(lang)". }
        } ORDER BY DESC(?links) LIMIT 2500
        """
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "https://query.wikidata.org/sparql?format=json&query=\(encoded)") else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 45)
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        await wikidataSlot()
        let result = try? await session.data(for: request)
        releaseWikidataSlot()
        guard let (data, response) = result,
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(SPARQLResponse.self, from: data) else { return [] }

        // Rows repeat per collection/genre: merge them per item, keeping the fame order.
        var order: [String] = []
        var items: [String: Artwork] = [:]
        var genres: [String: Set<String>] = [:]
        for row in payload.results.bindings {
            guard let itemURI = row["item"]?.value, let qid = itemURI.split(separator: "/").last.map(String.init) else { continue }
            if let genre = row["genre"]?.value.split(separator: "/").last { genres[qid, default: []].insert(String(genre)) }
            guard items[qid] == nil,
                  let title = row["itemLabel"]?.value, title != qid,           // skip works without a label
                  let file = row["image"]?.value else { continue }
            let base = file.replacingOccurrences(of: "http://", with: "https://")
            guard let full = URL(string: base + "?width=3840"), let thumb = URL(string: base + "?width=960") else { continue }
            var place = row["collectionLabel"]?.value ?? ""
            if place.hasPrefix("http") || place.hasPrefix("Q") { place = "" }
            items[qid] = Artwork(id: "wd-\(qid)", title: title,
                                 artist: row["creatorLabel"]?.value ?? artist.name,
                                 date: row["year"]?.value ?? "",
                                 imageURL: full, thumbnailURL: thumb,
                                 source: place.isEmpty ? "Wikimedia Commons" : place,
                                 detailURL: URL(string: "https://www.wikidata.org/wiki/\(qid)"),
                                 isPainting: true,
                                 popularity: Int(row["links"]?.value ?? ""))
            order.append(qid)
        }
        return order.compactMap { qid in
            guard var art = items[qid] else { return nil }
            art.genres = genres[qid].map { Array($0) }
            return art
        }
    }

    static let userAgent = "TVArt/1.0 (https://github.com/LRvdLinden/TVArt) tvOS"

    private func museums(_ artist: Artist) async -> [Artwork] {
        let perTerm = max(8, 32 / max(1, artist.metTerms.count))
        let combined = await withTaskGroup(of: [Artwork].self) { group -> [Artwork] in
            // Met terms run one after another (inside a single task) to stay well below its rate limits.
            group.addTask {
                var items: [Artwork] = []
                for term in artist.metTerms { items += await self.met(term: term, keys: artist.keys, maxObjects: perTerm) }
                return items
            }
            for name in artist.clevelandNames {
                group.addTask { await self.cleveland(name: name, keys: artist.keys, limit: 100) }
            }
            var all: [Artwork] = []
            for await part in group { all += part }
            return all
        }
        var seen = Set<String>()
        let unique = combined.filter { seen.insert($0.id).inserted }
        // Paintings first, then drawings/prints; alphabetical within each group.
        return unique.sorted {
            let p0 = $0.isPainting == true, p1 = $1.isPainting == true
            if p0 != p1 { return p0 }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    // MARK: Cleveland

    private func cleveland(name: String, keys: [String], limit: Int) async -> [Artwork] {
        var components = URLComponents(string: "https://openaccess-api.clevelandart.org/api/artworks/")!
        components.queryItems = [
            URLQueryItem(name: "artists", value: name),
            URLQueryItem(name: "has_image", value: "1"),
            URLQueryItem(name: "cc0", value: "1"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "fields", value: "id,title,creation_date,creators,images,type,url")
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(CMAResponse.self, from: data) else { return [] }
        return payload.data.compactMap { item in
            let maker = item.creators?.first?.description ?? ""
            guard Self.matches(maker, keys: keys),
                  let web = item.images?.web?.url, let thumb = URL(string: web) else { return nil }
            let full = URL(string: item.images?.print?.url ?? "") ?? thumb
            // "Vincent van Gogh (Dutch, 1853–1890)" → "Vincent van Gogh"
            let artistName = maker.components(separatedBy: " (").first ?? maker
            return Artwork(id: "cma-\(item.id)", title: item.title ?? String(localized: "Untitled"),
                           artist: artistName, date: item.creation_date ?? "",
                           imageURL: full, thumbnailURL: thumb,
                           source: "Cleveland Museum of Art",
                           detailURL: URL(string: item.url ?? ""),
                           isPainting: item.type == "Painting")
        }
    }

    // MARK: The Met

    private func met(term: String, keys: [String], maxObjects: Int) async -> [Artwork] {
        guard !metBlocked else { return [] }
        var components = URLComponents(string: "https://collectionapi.metmuseum.org/public/collection/v1.1/search")!
        components.queryItems = [URLQueryItem(name: "q", value: term),
                                 URLQueryItem(name: "hasImages", value: "true"),
                                 URLQueryItem(name: "artistOrCulture", value: "true"),
                                 URLQueryItem(name: "limit", value: "100")]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url) else { return [] }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 403 || status == 429 { metBlocked = true; return [] }
        guard status == 200, let ids = try? JSONDecoder().decode(MetSearch.self, from: data).objectIDs else { return [] }

        // Object details in small parallel batches, stopping once we have enough.
        var output: [Artwork] = []
        let candidates = Array(ids.prefix(maxObjects * 2))
        var index = 0
        while index < candidates.count && output.count < maxObjects && !Task.isCancelled && !metBlocked {
            let batch = Array(candidates[index..<min(index + 3, candidates.count)])
            index += batch.count
            let results = await withTaskGroup(of: Artwork?.self) { group -> [Artwork] in
                for id in batch { group.addTask { await self.metObject(id: id, keys: keys) } }
                var items: [Artwork] = []
                for await item in group { if let item { items.append(item) } }
                return items
            }
            output += results
        }
        return output
    }

    private func metObject(id: Int, keys: [String]) async -> Artwork? {
        guard !metBlocked,
              let url = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1/objects/\(id)"),
              let (data, response) = try? await session.data(from: url) else { return nil }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 403 || status == 429 { metBlocked = true; return nil }
        guard status == 200,
              let item = try? JSONDecoder().decode(MetObject.self, from: data),
              item.isPublicDomain == true,
              let artist = item.artistDisplayName, Self.matches(artist, keys: keys),
              let imageString = item.primaryImage, !imageString.isEmpty,
              let image = URL(string: imageString) else { return nil }
        let thumb = URL(string: item.primaryImageSmall ?? "") ?? image
        return Artwork(id: "met-\(item.objectID)", title: item.title ?? String(localized: "Untitled"), artist: artist,
                       date: item.objectDate ?? "", imageURL: image, thumbnailURL: thumb,
                       source: "The Metropolitan Museum of Art", detailURL: URL(string: item.objectURL ?? ""),
                       isPainting: item.classification == "Paintings")
    }

    private static func matches(_ artist: String, keys: [String]) -> Bool {
        let a = artist.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        guard !a.isEmpty else { return false }
        return keys.contains { a.contains($0) }
    }
}
