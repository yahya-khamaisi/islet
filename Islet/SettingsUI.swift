import ServiceManagement
import SwiftUI

// Pieces shared by the menu-bar panel and the settings window. Unlike the island, these
// use stock controls and follow the system's light or dark appearance.

/// System Settings–style icon: white SF Symbol on a tinted rounded square.
struct IconTile: View {
    let symbol: String
    let tint: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(tint.gradient, in: .rect(cornerRadius: 6, style: .continuous))
    }
}

extension IslandModel.App {
    var tile: IconTile { IconTile(symbol: symbol, tint: tint) }
}

/// A grouped Form that sizes itself to its content, so a panel never scrolls needlessly.
struct FittedForm<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 300

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.top, -4, for: .scrollContent)
            .contentMargins(.bottom, -4, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentSize.height + $0.contentInsets.top + $0.contentInsets.bottom }) { _, new in
                height = new
            }
            .frame(height: min(max(height, 80), 640))
    }
}

/// An app's name, its status underneath, and a tile.
struct AppLabel: View {
    let app: IslandModel.App
    let status: String
    var body: some View {
        HStack(spacing: 10) {
            app.tile
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Status lines and connect actions, worded the same everywhere they appear.
@MainActor
enum Connection {
    static func spotify(_ spotify: Spotify) -> String {
        if spotify.isBlocked { return "Needs Automation access" }
        if !spotify.isRunning { return "Not open" }
        return spotify.isPlaying ? "Playing" : "Connected"
    }

    static func outlook(_ calendar: OutlookCalendar) -> String {
        switch calendar.access {
        case .notAsked: "Not connected"
        case .denied: "Calendar access is off"
        case .granted: calendar.usesOutlookAccount ? "Connected" : "No Outlook account in Calendar"
        }
    }

    static func claude(_ agents: AgentStore) -> String {
        guard agents.hooksInstalled else { return "Not connected" }
        let running = agents.runningCount
        return running > 0 ? "\(running) running" : "Connected"
    }

    /// Adds or removes the hooks; returns an error to show, if any.
    static func setClaude(_ on: Bool, _ agents: AgentStore) -> String? {
        defer { agents.hooksInstalled = HookInstaller.isInstalled }
        do {
            try on ? HookInstaller.install() : HookInstaller.uninstall()
            return nil
        } catch {
            return "Couldn't edit ~/.claude/settings.json."
        }
    }

    static func openPrivacy(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }
}

/// Open at login, through the system's login items.
struct LoginItemToggle: View {
    @State private var on = SMAppService.mainApp.status == .enabled
    var body: some View {
        Toggle("Open at login", isOn: Binding(get: { on }, set: { new in
            try? new ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            on = SMAppService.mainApp.status == .enabled
        }))
    }
}

/// Minutes, written the way people say them.
func minutesLabel(_ minutes: Int) -> String {
    minutes < 60 ? "\(minutes) minute\(minutes == 1 ? "" : "s")" : "\(minutes / 60) hour\(minutes == 60 ? "" : "s")"
}
