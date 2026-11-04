import AppKit
import Observation
import SwiftUI

enum Defaults {
    static let openOnHover = "openOnHover"
    static let widenForAgents = "widenForAgents"
    static let approvalWait = "approvalWait"
    static let hookToken = "hookToken"

    static func register() {
        UserDefaults.standard.register(defaults: [
            openOnHover: true,
            widenForAgents: true,
            approvalWait: 60,
        ])
    }
}

/// What the notch is showing, and how big it is on screen.
@Observable @MainActor
final class NotchModel {
    enum Tab: String, CaseIterable, Identifiable {
        case home, agents, calendar
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    enum Page: Equatable {
        case tab(Tab)
        case settings
    }

    var isOpen = false
    var page: Page = .tab(.home)
    /// Keeps the notch open after the pointer leaves.
    var isPinned = false
    /// The hardware notch, or a stand-in on Macs without one.
    var notchSize = CGSize(width: 200, height: 32)
    var hasNotch = true
    /// The notch's current size as drawn, used for hit-testing.
    var drawnSize = CGSize.zero

    /// `pinned` keeps it open until a click elsewhere, for opening from the menu bar.
    func open(_ page: Page? = nil, pinned: Bool = false) {
        if let page { self.page = page }
        if pinned { isPinned = true }
        guard !isOpen else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isOpen = true }
    }

    func close() {
        guard isOpen else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
            isOpen = false
            isPinned = false
            if page == .settings { page = .tab(.home) }
        }
    }

    func show(_ page: Page) {
        withAnimation(.snappy(duration: 0.28)) { self.page = page }
    }
}
