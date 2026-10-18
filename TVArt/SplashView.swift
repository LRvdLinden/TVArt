import SwiftUI

/// Cinematic opening: the painting slowly comes into focus under a gallery spotlight,
/// the gilded TVArt wordmark appears, a light sweep glides over it and the tagline fades in.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var artVisible = false
    @State private var artScale: CGFloat = 1.16
    @State private var artBlur: CGFloat = 18
    @State private var spotlight = false
    @State private var wordVisible = false
    @State private var shimmer: CGFloat = -1
    @State private var lineWidth: CGFloat = 0
    @State private var taglineVisible = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.ink

                Image("SplashArt")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(artScale)
                    .blur(radius: artBlur)
                    .opacity(artVisible ? 1 : 0)
                    .clipped()

                // Cinematic vignette + darker lower third for the type.
                RadialGradient(colors: [.clear, .black.opacity(0.88)],
                               center: .center,
                               startRadius: geo.size.width * 0.16,
                               endRadius: geo.size.width * 0.78)
                LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)

                // Warm gallery spotlight from above.
                RadialGradient(colors: [Color(red: 1, green: 0.86, blue: 0.62).opacity(spotlight ? 0.28 : 0), .clear],
                               center: UnitPoint(x: 0.5, y: -0.05),
                               startRadius: 0,
                               endRadius: geo.size.height * 0.95)
                    .blendMode(.screen)

                VStack(spacing: 22) {
                    Wordmark(size: 210, shimmer: shimmer)
                        .scaleEffect(wordVisible ? 1 : 1.12)
                        .blur(radius: wordVisible ? 0 : 22)
                        .opacity(wordVisible ? 1 : 0)

                    Capsule()
                        .fill(Theme.gold)
                        .frame(width: lineWidth, height: 3)

                    Text("Meesterwerken op je grootste scherm")
                        .font(Theme.displayMedium(44))
                        .tracking(3)
                        .foregroundStyle(Theme.paper.opacity(0.9))
                        .opacity(taglineVisible ? 1 : 0)
                        .offset(y: taglineVisible ? 0 : 14)
                }
                .padding(.horizontal, 120)
                .padding(.vertical, 60)
                .background(
                    Ellipse()
                        .fill(Color.black.opacity(wordVisible ? 0.5 : 0))
                        .blur(radius: 90)
                )
                .offset(y: geo.size.height * 0.06)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TVArt. Meesterwerken op je grootste scherm.")
        .task { await play() }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    @MainActor private func play() async {
        if reduceMotion {
            artScale = 1; artBlur = 0
            withAnimation(.easeInOut(duration: 0.6)) { artVisible = true; spotlight = true; wordVisible = true; lineWidth = 380; taglineVisible = true }
            await pause(1.8)
            onFinish()
            return
        }
        withAnimation(.easeOut(duration: 1.4)) { artVisible = true; spotlight = true }
        withAnimation(.easeOut(duration: 2.2)) { artBlur = 0 }
        withAnimation(.easeOut(duration: 4.2)) { artScale = 1.0 }
        await pause(0.55)
        withAnimation(.spring(response: 1.1, dampingFraction: 0.9)) { wordVisible = true }
        shimmer = 0
        await pause(0.85)
        withAnimation(.easeInOut(duration: 0.8)) { lineWidth = 380 }
        withAnimation(.easeInOut(duration: 1.25)) { shimmer = 1 }
        await pause(0.35)
        withAnimation(.easeOut(duration: 0.8)) { taglineVisible = true }
        await pause(1.6)
        onFinish()
    }
}
