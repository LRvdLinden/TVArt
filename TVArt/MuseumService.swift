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
        let dir = base.appendingPathComponent("TVArtCollections", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func readDisk(_ id: String) -> [Artwork]? {
        guard let data = try? Data(contentsOf: diskDir.appendingPathComponent("\(id).json")),
              let entry = try? JSONDecoder().decode(DiskEntry.self, from: data),
              Date().timeIntervalSince(entry.date) < 7 * 24 * 3600, !entry.artworks.isEmpty else { return nil }
        return entry.artworks
    }

    private func writeDisk(_ id: String, _ artworks: [Artwork]) {
        guard let data = try? JSONEncoder().encode(DiskEntry(date: Date(), artworks: artworks)) else { return }
        try? data.write(to: diskDir.appendingPathComponent("\(id).json"), options: .atomic)
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

    /// A representative thumbnail for the home screen (one quick Cleveland request, Met as fallback).
    func cover(for artist: Artist) async -> URL? {
        if let url = covers[artist.id] { return url }
        if cache[artist.id] == nil, let disk = readDisk(artist.id) { cache[artist.id] = disk }
        if let first = cache[artist.id]?.first { covers[artist.id] = first.thumbnailURL; return first.thumbnailURL }
        var found = await cleveland(name: artist.clevelandNames[0], keys: artist.keys, limit: 15)
            .sorted { ($0.isPainting == true) && ($1.isPainting != true) }.first?.thumbnailURL
        if found == nil {
            found = await met(term: artist.metTerms[0], keys: artist.keys, maxObjects: 3).first?.thumbnailURL
        }
        if let found { covers[artist.id] = found }
        return found
    }

    func prefetchCovers(for artists: [Artist]) async {
        await withTaskGroup(of: Void.self) { group in
            for artist in artists.prefix(8) { group.addTask { _ = await self.cover(for: artist) } }
        }
    }

    private func fetch(_ artist: Artist) async -> [Artwork] {
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
