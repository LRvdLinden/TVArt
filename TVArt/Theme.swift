import SwiftUI

/// Visual language of TVArt: dark museum hall, oxblood walls and gilded accents.
enum Theme {
    static let ink = Color(red: 0.035, green: 0.030, blue: 0.035)
    static let wall = Color(red: 0.23, green: 0.06, blue: 0.09)
    static let wallDeep = Color(red: 0.11, green: 0.03, blue: 0.05)
    static let goldSolid = Color(red: 0.86, green: 0.70, blue: 0.38)
    static let paper = Color(red: 0.95, green: 0.92, blue: 0.86)

    static let gold = LinearGradient(
        colors: [Color(red: 1.00, green: 0.94, blue: 0.76),
                 Color(red: 0.90, green: 0.72, blue: 0.38),
                 Color(red: 0.62, green: 0.43, blue: 0.17)],
        startPoint: .top, endPoint: .bottom)

    static let hall = LinearGradient(colors: [wall, wallDeep, ink], startPoint: .top, endPoint: .bottom)

    /// Bundled Cormorant Garamond (SIL OFL). Falls back to the system font when unavailable.
    static func display(_ size: CGFloat) -> Font { .custom("CormorantGaramond-SemiBold", size: size) }
    static func displayMedium(_ size: CGFloat) -> Font { .custom("CormorantGaramond-Medium", size: size) }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// The TVArt wordmark in gilded type with an optional light sweep.
struct Wordmark: View {
    var size: CGFloat
    var shimmer: CGFloat = -1   // -1 = no sweep, 0…1 = sweep position

    var body: some View {
        let word = Text("TVArt").font(Theme.display(size))
        word
            .foregroundStyle(Theme.gold)
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.35)
                        .offset(x: shimmer * g.size.width * 1.4 - g.size.width * 0.4)
                        .opacity(shimmer < 0 ? 0 : 1)
                }
                .mask { word }
            }
            .shadow(color: .black.opacity(0.55), radius: size * 0.08, y: size * 0.03)
            .accessibilityLabel("TVArt")
    }
}
