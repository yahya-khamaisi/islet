import AppKit
import Observation
import SwiftUI

enum Defaults {
    static let enabled = "enabled"
    static let spotifyEnabled = "spotifyEnabled"
    static let claudeEnabled = "claudeEnabled"
    static let outlookEnabled = "outlookEnabled"
    static let expandForApprovals = "expandForApprovals"
    static let alertSeconds = "alertSeconds"
    static let meetingLead = "meetingLead"
    static let pausedGrace = "pausedGrace"
    static let finishedVisible = "finishedVisible"
    static let approvalWait = "approvalWait"
    static let approvalShortcuts = "approvalShortcuts"
    static let hookToken = "hookToken"

    static func register() {
        UserDefaults.standard.register(defaults: [
            enabled: true,
            spotifyEnabled: true,
            claudeEnabled: true,
            outlookEnabled: true,
            expandForApprovals: true,
            alertSeconds: 8,
            meetingLead: 15,
            pausedGrace: 5,
            finishedVisible: 30,
            approvalWait: 60,
            approvalShortcuts: true,
        ])
    }
}

/// What the island shows, and how big it is on screen.
@Observable @MainActor
final class IslandModel {
    enum App: String, CaseIterable, Identifiable {
        case spotify, claude, outlook
        var id: Self { self }
        var name: String {
            switch self {
            case .spotify: "Spotify"
            case .claude: "Claude Code"
            case .outlook: "Outlook"
            }
        }
        var symbol: String {
            switch self {
            case .spotify: "music.note"
            case .claude: "sparkle"
            case .outlook: "calendar"
            }
        }
        var tint: Color {
            switch self {
            case .spotify: Palette.spotify
            case .claude: Palette.claude
            case .outlook: Palette.outlook
            }
        }
        var panelWidth: CGFloat {
            switch self {
            case .claude: 420
            case .spotify, .outlook: 380
            }
        }
    }

    enum Expansion: Equatable {
        case panel(App)
        /// A Claude Code session that needs you, shown without being asked.
        case alert(session: String)
    }

    /// nil while the island is compact.
    private(set) var expansion: Expansion?
    /// Apps shown beside the notch, nearest the notch first.
    var leading: [App] = []
    var trailing: [App] = []
    /// The slot under the pointer, highlighted only; hovering never opens anything.
    var hovered: App?
    var notchSize = CGSize(width: 185, height: 32)
    var hasNotch = true
    /// The island's current size as drawn, used for hit-testing.
    var drawnSize = CGSize.zero
    var isPointerInside = false

    private var alertTask: Task<Void, Never>?

    func open(_ app: App) {
        alertTask?.cancel()
        set(.panel(app))
    }

    func close() {
        alertTask?.cancel()
        set(nil)
    }

    func toggle(_ app: App) {
        expansion == .panel(app) ? close() : open(app)
    }

    /// Expands for a waiting agent, then shrinks back after `alertSeconds`, or once the
    /// pointer leaves if it's resting on the island then.
    func alert(session: String) {
        guard expansion == nil || expansion.map({ if case .alert = $0 { true } else { false } }) == true else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        set(.alert(session: session))
        alertTask?.cancel()
        let seconds = max(3, UserDefaults.standard.integer(forKey: Defaults.alertSeconds))
        alertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            while self?.isPointerInside == true { try? await Task.sleep(for: .seconds(1)) }
            guard !Task.isCancelled, let self, case .alert = self.expansion else { return }
            self.set(nil)
        }
    }

    private func set(_ new: Expansion?) {
        guard new != expansion else { return }
        if new != nil, expansion == nil {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        withAnimation(.spring(response: 0.42, dampingFraction: new == nil ? 0.9 : 0.8)) { expansion = new }
    }

    /// Which slot sits under `x`, measured from the island's centre.
    func slot(atOffset x: CGFloat) -> App? {
        let edge = notchSize.width / 2
        let index = Int((abs(x) - edge) / Metrics.slot)
        guard abs(x) >= edge, index >= 0 else { return nil }
        let side = x < 0 ? leading : trailing
        return index < side.count ? side[index] : nil
    }
}
