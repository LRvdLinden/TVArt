import AVFoundation
import SwiftUI

/// Soft classical music behind the art: three public-domain recordings that loop one after another.
/// Files come from Wikimedia Commons (MP3 transcodes) and are kept on the Apple TV after the first play.
@MainActor final class BackgroundMusic: ObservableObject {
    static let shared = BackgroundMusic()

    struct Track: Identifiable {
        let id: String
        let title: String
        let composer: String
        let performer: String
        let url: URL
    }

    static let tracks: [Track] = [
        Track(id: "debussy-clair-de-lune", title: "Clair de lune", composer: "Claude Debussy", performer: "Musopen",
              url: URL(string: "https://upload.wikimedia.org/wikipedia/commons/transcoded/b/be/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg/Clair_de_lune_%28Claude_Debussy%29_Suite_bergamasque.ogg.mp3")!),
        Track(id: "satie-gymnopedie-1", title: "Gymnopédie No. 1", composer: "Erik Satie", performer: "Michael Laucke",
              url: URL(string: "https://upload.wikimedia.org/wikipedia/commons/transcoded/a/a6/Satie_Gymnopedie_No_1_performed_by_Michael_Laucke.flac/Satie_Gymnopedie_No_1_performed_by_Michael_Laucke.flac.mp3")!),
        Track(id: "chopin-nocturne-op9-2", title: "Nocturne Op. 9 No. 2", composer: "Frédéric Chopin", performer: "Frank Lévy",
              url: URL(string: "https://upload.wikimedia.org/wikipedia/commons/transcoded/8/89/Chopin_-_Nocturne_No._2_in_E-flat_major%2C_Op._9_No._2_%28Frank_Levy%29.flac/Chopin_-_Nocturne_No._2_in_E-flat_major%2C_Op._9_No._2_%28Frank_Levy%29.flac.mp3")!)
    ]

    @Published private(set) var nowPlaying: Track?

    private let player = AVPlayer()
    private var index = 0
    private var targetVolume: Float = 0.2
    private var wantsToPlay = false
    private var endObserver: NSObjectProtocol?
    private var fadeTask: Task<Void, Never>?

    private let folder: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TVArtMusic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        player.volume = 0
        player.actionAtItemEnd = .pause
        // Mix with other audio and never interrupt it; stays quiet when the TV is muted.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                             object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self, (note.object as? AVPlayerItem) === self.player.currentItem else { return }
                self.index = (self.index + 1) % Self.tracks.count   // 1 → 2 → 3 → 1 …
                await self.playCurrent()
            }
        }
    }

    /// Applies the user's settings: starts, stops or changes the volume.
    func update(enabled: Bool, volume: Float) {
        targetVolume = volume
        if enabled {
            guard !wantsToPlay else { fade(to: volume, seconds: 1.0); return }
            wantsToPlay = true
            try? AVAudioSession.sharedInstance().setActive(true)
            Task { await playCurrent() }
        } else {
            wantsToPlay = false
            fade(to: 0, seconds: 1.5) { [weak self] in self?.player.pause() }
        }
    }

    /// Pause/resume with the app (e.g. when the TV goes to the Home screen).
    func appBecameActive(_ active: Bool) {
        guard wantsToPlay else { return }
        if active {
            player.play()
            fade(to: targetVolume, seconds: 2)
        } else {
            player.pause()
        }
    }

    private func playCurrent() async {
        guard wantsToPlay else { return }
        let track = Self.tracks[index]
        guard let file = await localFile(for: track) else {
            // Offline or unavailable: try the next piece in a minute.
            try? await Task.sleep(for: .seconds(60))
            index = (index + 1) % Self.tracks.count
            await playCurrent()
            return
        }
        guard wantsToPlay else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: file))
        nowPlaying = track
        player.volume = 0
        player.play()
        fade(to: targetVolume, seconds: 4)
    }

    /// Downloads a track once and keeps it in Caches, so later loops play offline.
    private func localFile(for track: Track) async -> URL? {
        let file = folder.appendingPathComponent("\(track.id).mp3")
        if FileManager.default.fileExists(atPath: file.path) { return file }
        var request = URLRequest(url: track.url, timeoutInterval: 60)
        request.setValue(MuseumService.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (temp, response) = try? await URLSession.shared.download(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        try? FileManager.default.removeItem(at: file)
        guard (try? FileManager.default.moveItem(at: temp, to: file)) != nil else { return nil }
        return file
    }

    private func fade(to volume: Float, seconds: Double, completion: (() -> Void)? = nil) {
        fadeTask?.cancel()
        let start = player.volume
        fadeTask = Task { @MainActor [weak self] in
            let steps = 30
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(Int(seconds * 1000) / steps))
                guard let self, !Task.isCancelled else { return }
                self.player.volume = start + (volume - start) * Float(step) / Float(steps)
            }
            completion?()
        }
    }
}
