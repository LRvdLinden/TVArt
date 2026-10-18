import SwiftUI

struct Artist: Identifiable, Hashable {
    let id: String
    let name: String
    let years: String
    let terms: [String]
    let symbol: String
    let isCollection: Bool

    static let collection: [Artist] = [
        .init(id: "vangogh", name: "Vincent van Gogh", years: "1853–1890", terms: ["Vincent van Gogh"], symbol: "sun.max", isCollection: false),
        .init(id: "rembrandt", name: "Rembrandt van Rijn", years: "1606–1669", terms: ["Rembrandt van Rijn", "Rembrandt"], symbol: "person.crop.rectangle", isCollection: false),
        .init(id: "monet", name: "Claude Monet", years: "1840–1926", terms: ["Claude Monet"], symbol: "water.waves", isCollection: false),
        .init(id: "mondrian", name: "Piet Mondriaan", years: "1872–1944", terms: ["Piet Mondrian", "Piet Mondriaan"], symbol: "square.grid.3x3", isCollection: false),
        .init(id: "renaissance", name: "Renaissance", years: "1400–1600", terms: ["Leonardo da Vinci", "Raphael", "Sandro Botticelli", "Titian"], symbol: "building.columns", isCollection: true),
        .init(id: "gauguin", name: "Paul Gauguin", years: "1848–1903", terms: ["Paul Gauguin"], symbol: "leaf", isCollection: false),
        .init(id: "manet", name: "Édouard Manet", years: "1832–1883", terms: ["Édouard Manet", "Edouard Manet"], symbol: "paintbrush.pointed", isCollection: false),
        .init(id: "munch", name: "Edvard Munch", years: "1863–1944", terms: ["Edvard Munch"], symbol: "moon.stars", isCollection: false),
        .init(id: "goya", name: "Francisco Goya", years: "1746–1828", terms: ["Francisco Goya", "Francisco de Goya"], symbol: "eye", isCollection: false),
        .init(id: "vermeer", name: "Johannes Vermeer", years: "1632–1675", terms: ["Johannes Vermeer"], symbol: "lightbulb", isCollection: false),
        .init(id: "cezanne", name: "Paul Cézanne", years: "1839–1906", terms: ["Paul Cézanne", "Paul Cezanne"], symbol: "mountain.2", isCollection: false),
        .init(id: "renoir", name: "Pierre-Auguste Renoir", years: "1841–1919", terms: ["Pierre-Auguste Renoir", "Auguste Renoir"], symbol: "figure.dance", isCollection: false),
        .init(id: "degas", name: "Edgar Degas", years: "1834–1917", terms: ["Edgar Degas"], symbol: "figure.skating", isCollection: false),
        .init(id: "turner", name: "J. M. W. Turner", years: "1775–1851", terms: ["Joseph Mallord William Turner", "J. M. W. Turner"], symbol: "cloud.sun", isCollection: false),
        .init(id: "hokusai", name: "Katsushika Hokusai", years: "1760–1849", terms: ["Katsushika Hokusai", "Hokusai"], symbol: "water.waves", isCollection: false),
        .init(id: "botticelli", name: "Sandro Botticelli", years: "1445–1510", terms: ["Sandro Botticelli"], symbol: "sparkles", isCollection: false),
        .init(id: "dali", name: "Salvador Dalí", years: "1904–1989", terms: ["Salvador Dali", "Salvador Dalí"], symbol: "clock", isCollection: false),
        .init(id: "klimt", name: "Gustav Klimt", years: "1862–1918", terms: ["Gustav Klimt"], symbol: "circle.hexagongrid", isCollection: false)
    ]
}

struct Artwork: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let artist: String
    let date: String
    let imageURL: URL
    let thumbnailURL: URL
    let source: String
    let detailURL: URL?
}

enum FitMode: Int, CaseIterable, Identifiable {
    case automatic = 0, fit = 1, fill = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .automatic: return "Automatisch"
        case .fit: return "Volledig werk tonen"
        case .fill: return "Beeldvullend"
        }
    }
}

/// User settings persisted in UserDefaults. Uses @Published so every change refreshes the UI
/// (@AppStorage inside an ObservableObject does not reliably publish changes).
@MainActor final class GallerySettings: ObservableObject {
    private let store = UserDefaults.standard

    @Published var duration: Int { didSet { store.set(duration, forKey: Keys.duration) } }
    @Published var clock: Bool { didSet { store.set(clock, forKey: Keys.clock) } }
    @Published var random: Bool { didSet { store.set(random, forKey: Keys.random) } }
    @Published var zoom: Bool { didSet { store.set(zoom, forKey: Keys.zoom) } }
    @Published var hints: Bool { didSet { store.set(hints, forKey: Keys.hints) } }
    @Published var captions: Bool { didSet { store.set(captions, forKey: Keys.captions) } }
    @Published var fitModeRaw: Int { didSet { store.set(fitModeRaw, forKey: Keys.fit) } }
    @Published private(set) var favoriteArtworks: [Artwork] = []

    var fitMode: FitMode { FitMode(rawValue: fitModeRaw) ?? .automatic }
    var favorites: Set<String> { Set(favoriteArtworks.map(\.id)) }

    private enum Keys {
        static let duration = "duration", clock = "clock", random = "random", zoom = "zoom"
        static let hints = "hints", captions = "captions", fit = "fitMode", favorites = "favoriteArtworks.v2"
    }

    init() {
        store.register(defaults: [Keys.duration: 30, Keys.clock: false, Keys.random: true, Keys.zoom: true,
                                  Keys.hints: true, Keys.captions: true, Keys.fit: 0])
        duration = store.integer(forKey: Keys.duration)
        clock = store.bool(forKey: Keys.clock)
        random = store.bool(forKey: Keys.random)
        zoom = store.bool(forKey: Keys.zoom)
        hints = store.bool(forKey: Keys.hints)
        captions = store.bool(forKey: Keys.captions)
        fitModeRaw = store.integer(forKey: Keys.fit)
        if let data = store.data(forKey: Keys.favorites),
           let saved = try? JSONDecoder().decode([Artwork].self, from: data) {
            favoriteArtworks = saved
        }
    }

    func isFavorite(_ artwork: Artwork) -> Bool { favoriteArtworks.contains { $0.id == artwork.id } }

    @discardableResult
    func toggleFavorite(_ artwork: Artwork) -> Bool {
        if let i = favoriteArtworks.firstIndex(where: { $0.id == artwork.id }) {
            favoriteArtworks.remove(at: i)
        } else {
            favoriteArtworks.insert(artwork, at: 0)
        }
        if let data = try? JSONEncoder().encode(favoriteArtworks) { store.set(data, forKey: Keys.favorites) }
        return isFavorite(artwork)
    }
}
