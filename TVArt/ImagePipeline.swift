import SwiftUI
import UIKit
import ImageIO

/// Downloads, decodes and caches artwork images so the slideshow can cross-fade without flashes.
actor ImagePipeline {
    static let shared = ImagePipeline()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 60
        c.totalCostLimit = 150_000_000
        return c
    }()
    private var running: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 25
        c.requestCachePolicy = .returnCacheDataElseLoad
        c.urlCache = URLCache(memoryCapacity: 20_000_000, diskCapacity: 500_000_000)
        // Wikimedia asks every client to identify itself.
        c.httpAdditionalHeaders = ["User-Agent": MuseumService.userAgent]
        return URLSession(configuration: c)
    }()

    func cached(_ url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func image(for url: URL) async -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        if let task = running[url] { return await task.value }
        let session = self.session
        let task = Task<UIImage?, Never> {
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode ?? 200 < 400 else { return nil }
            // Downsample huge museum scans (often 20+ MP) to 4K so the Apple TV never runs out of memory.
            let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                           kCGImageSourceShouldCacheImmediately: true,
                           kCGImageSourceCreateThumbnailWithTransform: true,
                           kCGImageSourceThumbnailMaxPixelSize: 3840] as CFDictionary
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
            return UIImage(cgImage: cg)
        }
        running[url] = task
        let image = await task.value
        running[url] = nil
        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            cache.setObject(image, forKey: url as NSURL, cost: cost)
        }
        return image
    }

    func prefetch(_ urls: [URL]) {
        for url in urls where cache.object(forKey: url as NSURL) == nil && running[url] == nil {
            Task { _ = await self.image(for: url) }
        }
    }
}

/// Async artwork image with a soft placeholder and fade-in.
struct ArtImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                LinearGradient(colors: [Theme.wall.opacity(0.9), Theme.wallDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: failed ? "photo.artframe" : "paintpalette")
                    .font(.system(size: 54, weight: .ultraLight))
                    .foregroundStyle(Theme.goldSolid.opacity(0.55))
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let hit = await ImagePipeline.shared.cached(url) { image = hit; return }
            let loaded = await ImagePipeline.shared.image(for: url)
            withAnimation(.easeOut(duration: 0.45)) {
                image = loaded
                failed = loaded == nil
            }
        }
        .accessibilityHidden(true)
    }
}
