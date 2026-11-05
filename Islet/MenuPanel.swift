import SwiftUI

/// The menu-bar panel: everyday settings, one switch per app, and the way to the rest.
struct MenuPanel: View {
    @Environment(Spotify.self) private var spotify
    @Environment(OutlookCalendar.self) private var calendar
    @Environment(AgentStore.self) private var agents
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Defaults.enabled) private var enabled = true
    @AppStorage(Defaults.spotifyEnabled) private var spotifyEnabled = true
    @AppStorage(Defaults.claudeEnabled) private var claudeEnabled = true
    @AppStorage(Defaults.outlookEnabled) private var outlookEnabled = true
    @AppStorage(Defaults.expandForApprovals) private var expandForApprovals = true
    @AppStorage(Defaults.meetingLead) private var meetingLead = 15
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                IconTile(symbol: "capsule.fill", tint: .black)
                Text("Islet").font(.headline)
                Spacer()
                Toggle("Islet", isOn: $enabled).toggleStyle(.switch).labelsHidden()
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)

            FittedForm {
                Section("Apps") {
                    Toggle(isOn: $spotifyEnabled) { AppLabel(app: .spotify, status: Connection.spotify(spotify)) }
                    if agents.hooksInstalled {
                        Toggle(isOn: $claudeEnabled) { AppLabel(app: .claude, status: Connection.claude(agents)) }
                    } else {
                        LabeledContent { Button("Connect") { error = Connection.setClaude(true, agents) } } label: {
                            AppLabel(app: .claude, status: error ?? Connection.claude(agents))
                        }
                    }
                    if calendar.access == .granted {
                        Toggle(isOn: $outlookEnabled) { AppLabel(app: .outlook, status: Connection.outlook(calendar)) }
                    } else {
                        LabeledContent { Button("Connect", action: calendar.requestAccess) } label: {
                            AppLabel(app: .outlook, status: Connection.outlook(calendar))
                        }
                    }
                }
                Section("Island") {
                    Toggle("Expand for approvals", isOn: $expandForApprovals)
                    Picker("Show meetings from", selection: $meetingLead) {
                        ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min before").tag($0) }
                    }
                }
            }
            .disabled(!enabled)

            HStack {
                Button("Advanced Settings…") {
                    openWindow(id: "settings")
                    NSApp.activate()
                }
                .keyboardShortcut(",")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .frame(width: 340)
        .onAppear { agents.hooksInstalled = HookInstaller.isInstalled }
    }
}
