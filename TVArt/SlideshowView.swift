import SwiftUI
import UIKit

private struct Slide: Identifiable, Equatable {
    let id = UUID()
    let artwork: Artwork
    let image: UIImage
    static func == (a: Slide, b: Slide) -> Bool { a.id == b.id }
}

/// Full-screen exhibition mode.
/// Remote: ◀ ▶ browse · ▲ favorite · ▼ / click artwork label · ⏯ pause · hold click: settings · Menu: back.
struct SlideshowView: View {
    let artworks: [Artwork]
    let startIndex: Int

    @EnvironmentObject var settings: GallerySettings
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    @State private var order: [Int] = []
    @State private var position = 0
    @State private var slide: Slide?
    @State private var loadingFailed = false
    @State private var paused = false
    @State private var showLabel = true
    @State private var labelToken = 0
    @State private var toast: String?
    @State private var toastToken = 0
    @State private var settingsOpen = false
    @State private var suppressNextTap = false
    @State private var target = 0          // position we are heading to (rapid presses add up)
    @State private var loadGeneration = 0  // only the newest load may update the screen

    private var current: Artwork? { order.isEmpty ? nil : artworks[order[position]] }

    var body: some View {
        ZStack {
            Color.black

            if let slide {
                SlideLayer(slide: slide, fitMode: settings.fitMode,
                           zoom: settings.zoom, duration: Double(settings.duration))
                    .id(slide.id)
                    .transition(.opacity)
            } else if loadingFailed {
                VStack(spacing: 18) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 70))
                    Text("This artwork couldn't be loaded. Press ▶ for the next one.")
                }
                .foregroundStyle(.secondary)
            } else {
                ProgressView().scaleEffect(1.4)
            }

            if let art = current, showLabel {
                placard(for: art)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if settings.clock { FloatingClock(raised: showLabel) }

            if let toast {
                Text(toast)
                    .font(.headline)
                    .padding(.horizontal, 30).padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .focusable(true)
        .focused($focused)
        .focusEffectDisabled()
        .onAppear {
            focused = true
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onLongPressGesture(minimumDuration: 0.8) {
            suppressNextTap = true
            settingsOpen = true
        }
        .onTapGesture {
            // Releasing a long press can also deliver a tap on some tvOS versions; ignore that one.
            if suppressNextTap { suppressNextTap = false; return }
            revealLabel(toggle: true)
        }
        .onPlayPauseCommand { togglePause() }
        .onMoveCommand { direction in
            switch direction {
            case .left: Task { await step(-1) }
            case .right: Task { await step(1) }
            case .up: toggleFavorite()
            case .down: revealLabel(toggle: true)
            @unknown default: break
            }
        }
        .onExitCommand {
            if showLabel { withAnimation(.easeInOut(duration: 0.4)) { showLabel = false } } else { dismiss() }
        }
        .fullScreenCover(isPresented: $settingsOpen, onDismiss: { focused = true; suppressNextTap = false }) { SettingsView() }
        .task { await start() }
        // Auto-advance timer; restarts whenever the slide, pause state or duration changes.
        .task(id: "\(position)-\(slide?.id.uuidString ?? "")-\(paused)-\(settings.duration)-\(settingsOpen)") {
            guard slide != nil || loadingFailed, !paused, !settingsOpen else { return }
            try? await Task.sleep(for: .seconds(settings.duration))
            guard !Task.isCancelled else { return }
            await step(1)
        }
        // Auto-hide the museum label.
        .task(id: labelToken) {
            guard showLabel else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.6)) { showLabel = false }
        }
        .task(id: toastToken) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation { toast = nil }
        }
    }

    // MARK: - Museum label

    private func placard(for art: Artwork) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Text(art.title)
                            .font(Theme.display(52))
                            .lineLimit(2)
                        if settings.isFavorite(art) {
                            Image(systemName: "heart.fill").font(.title2).foregroundStyle(Theme.goldSolid)
                        }
                    }
                    Text([art.artist, art.date].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(art.source).font(.caption).foregroundStyle(.white.opacity(0.6))
                    if settings.hints {
                        Text("◀ ▶ browse   ▲ favorite   ⏯ pause   hold click: settings")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.top, 10)
                    }
                }
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 8) {
                    if paused { Label("Paused", systemImage: "pause.fill").font(.headline) }
                    Text("\(position + 1) / \(order.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 90)
            .padding(.top, 140)
            .padding(.bottom, 70)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom))
        }
        .foregroundStyle(.white)
    }

    // MARK: - Actions

    private func start() async {
        guard order.isEmpty, !artworks.isEmpty else { return }
        let first = min(max(0, startIndex), artworks.count - 1)
        if settings.random {
            order = [first] + artworks.indices.filter { $0 != first }.shuffled()
        } else {
            order = Array(artworks.indices[first...]) + Array(artworks.indices[..<first])
        }
        position = 0
        target = 0
        await show(position: 0, in: order)
    }

    private func step(_ delta: Int) async {
        guard order.count > 0 else { return }
        var newOrder = order
        var next = target + delta
        if next >= newOrder.count {
            next = 0
            if settings.random && newOrder.count > 2 {
                let last = newOrder[min(target, newOrder.count - 1)]
                // New shuffle; the work we just saw goes last so it never repeats back-to-back.
                newOrder = artworks.indices.filter { $0 != last }.shuffled() + [last]
            }
        }
        if next < 0 { next = newOrder.count - 1 }
        target = next
        await show(position: next, in: newOrder)
    }

    private func show(position target: Int, in newOrder: [Int]) async {
        loadGeneration += 1
        let generation = loadGeneration
        let art = artworks[newOrder[target]]
        if slide == nil { loadingFailed = false }
        let image = await ImagePipeline.shared.image(for: art.imageURL)
        guard generation == loadGeneration, !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 1.1)) {
            order = newOrder
            position = target
            if let image {
                slide = Slide(artwork: art, image: image)
                loadingFailed = false
            } else {
                slide = nil
                loadingFailed = true
            }
        }
        if settings.captions { revealLabel(toggle: false) }
        // Preload the next two works for seamless cross-fades.
        let upcoming = (1...2).map { newOrder[(target + $0) % newOrder.count] }.map { artworks[$0].imageURL }
        await ImagePipeline.shared.prefetch(upcoming)
    }

    private func revealLabel(toggle: Bool) {
        withAnimation(.easeInOut(duration: 0.5)) { showLabel = toggle ? !showLabel : true }
        labelToken += 1
    }

    private func togglePause() {
        paused.toggle()
        flash(paused ? String(localized: "⏸  Paused") : String(localized: "▶  Resumed"))
    }

    private func toggleFavorite() {
        guard let art = current else { return }
        let isFav = settings.toggleFavorite(art)
        flash(isFav ? String(localized: "♥  Saved to favorites") : String(localized: "Removed from favorites"))
    }

    private func flash(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = text }
        toastToken += 1
    }
}

/// One artwork on screen: blurred backdrop for letterboxing plus a slow Ken Burns drift.
private struct SlideLayer: View {
    let slide: Slide
    let fitMode: FitMode
    let zoom: Bool
    let duration: Double
    @State private var drift = false
    @State private var anchor: UnitPoint = ([.center, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing] as [UnitPoint]).randomElement() ?? .center

    private var shouldFill: Bool {
        switch fitMode {
        case .fill: return true
        case .fit: return false
        case .automatic:
            let ratio = slide.image.size.width / max(slide.image.size.height, 1)
            return abs(ratio - 16.0 / 9.0) < 0.35   // close to widescreen → fill the screen
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: slide.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 70)
                    .overlay(Color.black.opacity(0.55))
                    .clipped()

                Image(uiImage: slide.image)
                    .resizable()
                    .aspectRatio(contentMode: shouldFill ? .fill : .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .shadow(color: .black.opacity(shouldFill ? 0 : 0.7), radius: 50)
                    .scaleEffect(drift ? 1.07 : 1.0, anchor: anchor)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .onAppear {
            guard zoom else { return }
            withAnimation(.linear(duration: duration + 3)) { drift = true }
        }
        .accessibilityLabel("\(slide.artwork.title), \(slide.artwork.artist)")
    }
}

/// Gently wandering clock to avoid burn-in on OLED TVs.
private struct FloatingClock: View {
    var raised: Bool
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let t = context.date.timeIntervalSince1970
            VStack {
                Spacer()
                Text(context.date, style: .time)
                    .font(Theme.display(54))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.8), radius: 10)
                    .offset(x: sin(t / 97) * 380, y: cos(t / 131) * 14)
                    .padding(.bottom, raised ? 300 : 50)
                    .animation(.easeInOut(duration: 0.6), value: raised)
            }
            .frame(maxWidth: .infinity)
        }
        .allowsHitTesting(false)
    }
}
