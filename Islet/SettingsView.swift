import ServiceManagement
import SwiftUI

/// Two groups of equal shape: where Islet's data comes from, and how the notch behaves.
struct SettingsView: View {
    @Environment(Spotify.self) private var spotify
    @Environment(OutlookCalendar.self) private var calendar
    @Environment(AgentStore.self) private var agents
    @AppStorage(Defaults.openOnHover) private var openOnHover = true
    @AppStorage(Defaults.widenForAgents) private var widenForAgents = true
    @AppStorage(Defaults.approvalWait) private var approvalWait = 60
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hookError: String?

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.gap) {
            SettingsGroup(title: "Sources") {
                Row(symbol: "music.note", tint: Palette.spotify, title: "Spotify") {
                    if spotify.isBlocked {
                        Button("Allow") { open("Privacy_Automation") }.buttonStyle(PillStyle())
                    } else {
                        Status(text: spotify.isRunning ? "Connected" : "Not open", good: spotify.isRunning)
                    }
                }
                Row(symbol: "calendar", tint: Palette.outlook, title: "Outlook") {
                    switch calendar.access {
                    case .granted: Status(text: calendar.usesOutlookAccount ? "Connected" : "No Outlook account", good: calendar.usesOutlookAccount)
                    case .notAsked: Button("Allow", action: calendar.requestAccess).buttonStyle(PillStyle())
                    case .denied: Button("Open settings", action: calendar.requestAccess).buttonStyle(PillStyle())
                    }
                }
                Row(symbol: "sparkle", tint: Palette.claude, title: "Claude Code") {
                    if let hookError {
                        Text(hookError).font(.system(size: 11)).foregroundStyle(Palette.attention).lineLimit(1)
                    }
                    if agents.hooksInstalled {
                        Button("Disconnect") { setHooks(false) }.buttonStyle(PillStyle())
                    } else {
                        Button("Connect") { setHooks(true) }.buttonStyle(PillStyle(fill: Palette.action))
                    }
                }
                Row(title: "Hold approvals for") {
                    Picker("Hold approvals for", selection: $approvalWait) {
                        Text("30 seconds").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("4 minutes").tag(240)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            SettingsGroup(title: "Notch") {
                Row(title: "Open on hover") { Switch(isOn: $openOnHover) }
                Row(title: "Widen when an agent needs you") { Switch(isOn: $widenForAgents) }
                Row(title: "Open at login") {
                    Switch(isOn: Binding(get: { openAtLogin }, set: { on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }))
                }
                Row(title: "Islet 0.1") {
                    Button("Quit Islet") { NSApp.terminate(nil) }.buttonStyle(PillStyle())
                }
            }
        }
        .onAppear { agents.hooksInstalled = HookInstaller.isInstalled }
    }

    private func setHooks(_ on: Bool) {
        do {
            try on ? HookInstaller.install() : HookInstaller.uninstall()
            hookError = nil
        } catch {
            hookError = "Couldn't edit settings.json"
        }
        agents.hooksInstalled = HookInstaller.isInstalled
    }

    private func open(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, Metrics.cardPadding)
                .frame(height: 32)
            content
        }
        .frame(maxWidth: .infinity)
        .background(Palette.fill, in: .rect(cornerRadius: Metrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5)
        }
    }
}

private struct Row<Trailing: View>: View {
    var symbol: String?
    var tint: Color = .white
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.16), in: .rect(cornerRadius: 6, style: .continuous))
            }
            Text(title).font(.system(size: 13)).lineLimit(1)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, Metrics.cardPadding)
        .frame(height: 44)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
    }
}

private struct Status: View {
    let text: String
    let good: Bool
    var body: some View {
        Text(text).font(.system(size: 12)).foregroundStyle(good ? Palette.done : Palette.secondary)
    }
}

private struct Switch: View {
    @Binding var isOn: Bool
    var body: some View {
        Toggle("", isOn: $isOn).toggleStyle(.switch).controlSize(.small).labelsHidden().tint(Palette.done)
    }
}
