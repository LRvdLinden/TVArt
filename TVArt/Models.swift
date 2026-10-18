import SwiftUI

struct Artist: Identifiable, Hashable {
    let id: String
    /// Localized display name.
    let name: String
    let years: String
    /// Search terms for The Met (v1.1 search).
    let metTerms: [String]
    /// Exact artist names for the Cleveland Museum of Art `artists=` filter.
    let clevelandNames: [String]
    /// Lower-case, accent-free tokens; an artwork only counts when its maker contains one of them.
    let keys: [String]
    let symbol: String
    let isCollection: Bool

    static let collection: [Artist] = [
        .init(id: "vangogh", name: "Vincent van Gogh", years: "1853–1890",
              metTerms: ["Vincent van Gogh"], clevelandNames: ["Vincent van Gogh"], keys: ["gogh"], symbol: "sun.max", isCollection: false),
        .init(id: "rembrandt", name: "Rembrandt van Rijn", years: "1606–1669",
              metTerms: ["Rembrandt"], clevelandNames: ["Rembrandt van Rijn"], keys: ["rembrandt"], symbol: "person.crop.rectangle", isCollection: false),
        .init(id: "monet", name: "Claude Monet", years: "1840–1926",
              metTerms: ["Claude Monet"], clevelandNames: ["Claude Monet"], keys: ["monet"], symbol: "water.waves", isCollection: false),
        .init(id: "vermeer", name: "Johannes Vermeer", years: "1632–1675",
              metTerms: ["Johannes Vermeer"], clevelandNames: ["Johannes Vermeer"], keys: ["vermeer"], symbol: "lightbulb", isCollection: false),
        .init(id: "renaissance", name: String(localized: "Renaissance"), years: "1400–1600",
              metTerms: ["Leonardo da Vinci", "Raphael", "Titian", "Botticelli"],
              clevelandNames: ["Leonardo da Vinci", "Raphael", "Titian", "Sandro Botticelli"],
              keys: ["leonardo", "raphael", "raffaello", "titian", "tiziano", "botticelli"], symbol: "building.columns", isCollection: true),
        .init(id: "hals", name: "Frans Hals", years: "1582–1666",
              metTerms: ["Frans Hals"], clevelandNames: ["Frans Hals"], keys: ["frans hals"], symbol: "theatermasks", isCollection: false),
        .init(id: "mondrian", name: String(localized: "Piet Mondrian"), years: "1872–1944",
              metTerms: ["Piet Mondrian"], clevelandNames: ["Piet Mondrian"], keys: ["mondria"], symbol: "square.grid.3x3", isCollection: false),
        .init(id: "gauguin", name: "Paul Gauguin", years: "1848–1903",
              metTerms: ["Paul Gauguin"], clevelandNames: ["Paul Gauguin"], keys: ["gauguin"], symbol: "leaf", isCollection: false),
        .init(id: "manet", name: "Édouard Manet", years: "1832–1883",
              metTerms: ["Edouard Manet"], clevelandNames: ["Édouard Manet"], keys: ["edouard manet"], symbol: "paintbrush.pointed", isCollection: false),
        .init(id: "munch", name: "Edvard Munch", years: "1863–1944",
              metTerms: ["Edvard Munch"], clevelandNames: ["Edvard Munch"], keys: ["munch"], symbol: "moon.stars", isCollection: false),
        .init(id: "goya", name: "Francisco Goya", years: "1746–1828",
              metTerms: ["Francisco de Goya"], clevelandNames: ["Francisco de Goya"], keys: ["goya"], symbol: "eye", isCollection: false),
        .init(id: "cezanne", name: "Paul Cézanne", years: "1839–1906",
              metTerms: ["Paul Cezanne"], clevelandNames: ["Paul Cézanne"], keys: ["cezanne"], symbol: "mountain.2", isCollection: false),
        .init(id: "renoir", name: "Pierre-Auguste Renoir", years: "1841–1919",
              metTerms: ["Auguste Renoir"], clevelandNames: ["Pierre-Auguste Renoir"], keys: ["renoir"], symbol: "figure.dance", isCollection: false),
        .init(id: "degas", name: "Edgar Degas", years: "1834–1917",
              metTerms: ["Edgar Degas"], clevelandNames: ["Edgar Degas"], keys: ["degas"], symbol: "figure.skating", isCollection: false),
        .init(id: "turner", name: "J. M. W. Turner", years: "1775–1851",
              metTerms: ["Joseph Mallord William Turner"], clevelandNames: ["Joseph Mallord William Turner"], keys: ["mallord william turner", "j. m. w. turner"], symbol: "cloud.sun", isCollection: false),
        .init(id: "hokusai", name: "Katsushika Hokusai", years: "1760–1849",
              metTerms: ["Katsushika Hokusai"], clevelandNames: ["Katsushika Hokusai"], keys: ["hokusai"], symbol: "water.waves", isCollection: false),
        .init(id: "botticelli", name: "Sandro Botticelli", years: "1445–1510",
              metTerms: ["Botticelli"], clevelandNames: ["Sandro Botticelli"], keys: ["botticelli"], symbol: "sparkles", isCollection: false),
        .init(id: "klimt", name: "Gustav Klimt", years: "1862–1918",
              metTerms: ["Gustav Klimt"], clevelandNames: ["Gustav Klimt"], keys: ["klimt"], symbol: "circle.hexagongrid", isCollection: false)
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
    var isPainting: Bool? = nil
}

enum FitMode: Int, CaseIterable, Identifiable {
    case automatic = 0, fit = 1, fill = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .automatic: return String(localized: "Automatic")
        case .fit: return String(localized: "Show whole artwork")
        case .fill: return String(localized: "Fill screen")
        }
    }
}

/// User settings persisted in UserDefaults. Uses @Published so every change refreshes the UI
/// (@AppStorage inside an ObservableObject does not reliably publish changes).
@MainActor final class GallerySettings: ObservableObject {
    private let store = UserDefaults.standard

    static let durations: [Int] = [20, 30, 60, 120, 300, 480]

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
            // Drop favorites from the retired Chicago source (its images are no longer reachable).
            favoriteArtworks = saved.filter { !$0.id.hasPrefix("aic-") }
        }
    }

    static func durationLabel(_ seconds: Int) -> String {
        seconds < 60 ? String(localized: "\(seconds) seconds") : String(localized: "\(seconds / 60) minutes")
    }

    func cycleDuration() {
        let all = Self.durations
        let i = all.firstIndex(of: duration) ?? 0
        duration = all[(i + 1) % all.count]
    }

    func cycleFitMode() { fitModeRaw = (fitModeRaw + 1) % FitMode.allCases.count }

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
