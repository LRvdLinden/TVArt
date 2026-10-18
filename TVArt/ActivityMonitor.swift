import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Notices every Siri Remote press or swipe anywhere in the app, so TVArt can start a
/// screensaver after a period of inactivity (like the system screensaver, but with art).
@MainActor final class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()

    private(set) var lastActivity = Date()
    /// True while an exhibition or screensaver is on screen (no auto-start needed then).
    var exhibitionActive = false
    private var installed = false

    func poke() { lastActivity = Date() }

    var idleSeconds: TimeInterval { Date().timeIntervalSince(lastActivity) }

    func install() {
        guard !installed else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return }
        let recognizer = ActivityRecognizer { [weak self] in self?.poke() }
        window.addGestureRecognizer(recognizer)
        installed = true
        poke()
    }
}

/// A gesture recognizer that never recognizes anything: it only reports that input happened.
private final class ActivityRecognizer: UIGestureRecognizer {
    private let onActivity: () -> Void

    init(onActivity: @escaping () -> Void) {
        self.onActivity = onActivity
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
        onActivity()
        state = .failed
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onActivity()
        state = .failed
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
