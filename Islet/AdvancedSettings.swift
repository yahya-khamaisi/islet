import SwiftUI

/// The settings window: a sidebar with one pane per area. Everyday switches live in the
/// menu-bar panel; everything else is here, in exactly one place.
struct AdvancedSettings: View {
    enum Pane: String, CaseIterable, Identifiable {
        case general, island, spotify, claude, outlook, about
        var id: Self { self }
        var title: String {
            switch self {
            case .general: "General"
            case .island: "Island"
            case .spotify: "Spotify"
            case .claude: "Claude Code"
            case .outlook: "Outlook"
            case .about: "About"
            }
        }
        var tile: IconTile {
            switch self {
            case .general: IconTile(symbol: "gearshape.fill", tint: .gray)
            case .island: IconTile(symbol: "capsule.fill", tint: .black)
            case .spotify: IslandModel.App.spotify.tile
            case .claude: IslandModel.App.claude.tile
            case .outlook: IslandModel.App.outlook.tile
            case .about: IconTile(symbol: "info", tint: .blue)
            }
        }
    }

    @State private var pane: Pane?

    init(pane: Pane = .general) {
        _pane = State(initialValue: pane)
    }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label { Text(pane.title) } icon: { pane.tile }
            }
            .navigationSplitViewColumnWidth(190)
        } detail: {
            Group {
                switch pane ?? .general {
                case .general: GeneralPane()
                case .island: IslandPane()
                case .spotify: SpotifyPane()
                case .claude: ClaudePane()
                case .outlook: OutlookPane()
                case .about: AboutPane()
                }
            }
            .formStyle(.grouped)
            .navigationTitle((pane ?? .general).title)
        }
        .frame(width: 700, height: 480)
    }
}

private struct GeneralPane: View {
    @AppStorage(Defaults.enabled) private var enabled = true
    var body: some View {
        Form {
            Section {
                Toggle("Show Islet", isOn: $enabled)
                LoginItemToggle()
            } footer: {
                Text("While Islet is off, the notch looks like it always does.")
            }
        }
    }
}

private struct IslandPane: View {
    @AppStorage(Defaults.expandForApprovals) private var expandForApprovals = true
    @AppStorage(Defaults.alertSeconds) private var alertSeconds = 8
    var body: some View {
        Form {
            Section {
                Toggle("Expand when an agent needs you", isOn: $expandForApprovals)
                Picker("Keep it expanded for", selection: $alertSeconds) {
                    ForEach([5, 8, 12, 20], id: \.self) { Text("\($0) seconds").tag($0) }
                }
                .disabled(!expandForApprovals)
            } header: {
                Text("Alerts")
            } footer: {
                Text("Nothing else opens by itself. Hovering only highlights an app; click or tap it to open its panel.")
            }
        }
    }
}

private struct SpotifyPane: View {
    @Environment(Spotify.self) private var spotify
    @AppStorage(Defaults.spotifyEnabled) private var spotifyEnabled = true
    @AppStorage(Defaults.pausedGrace) private var pausedGrace = 5
    var body: some View {
        Form {
            Section {
                Toggle("Show Spotify", isOn: $spotifyEnabled)
                Picker("After pausing, keep it for", selection: $pausedGrace) {
                    ForEach([1, 5, 15, 60], id: \.self) { Text(minutesLabel($0)).tag($0) }
                }
            }
            Section("Connection") {
                LabeledContent("Status", value: Connection.spotify(spotify))
                LabeledContent("Automation access") {
                    Button("Open Privacy Settings") { Connection.openPrivacy("Privacy_Automation") }
                }
                LabeledContent("Spotify") { Button("Open", action: spotify.launch) }
            }
        }
    }
}

private struct ClaudePane: View {
    @Environment(AgentStore.self) private var agents
    @AppStorage(Defaults.claudeEnabled) private var claudeEnabled = true
    @AppStorage(Defaults.approvalWait) private var approvalWait = 60
    @AppStorage(Defaults.finishedVisible) private var finishedVisible = 30
    @AppStorage(Defaults.approvalShortcuts) private var approvalShortcuts = true
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Toggle("Show Claude Code", isOn: $claudeEnabled)
                Picker("Show finished sessions for", selection: $finishedVisible) {
                    ForEach([5, 15, 30, 60], id: \.self) { Text(minutesLabel($0)).tag($0) }
                }
            }
            Section {
                Picker("Hold approvals for", selection: $approvalWait) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("4 minutes").tag(240)
                }
                Toggle("Approve with \(Shortcut.allow.display), deny with \(Shortcut.deny.display)", isOn: $approvalShortcuts)
                    .onChange(of: approvalShortcuts) { agents.syncShortcuts() }
            } header: {
                Text("Approvals")
            } footer: {
                Text("If you don't answer in time, the request goes back to Claude's own prompt. The shortcuts work only while a request is waiting.")
            }
            Section {
                LabeledContent("Status", value: error ?? Connection.claude(agents))
                LabeledContent("Hooks") {
                    HStack {
                        if agents.hooksInstalled {
                            Button("Reinstall") { error = Connection.setClaude(true, agents) }
                            Button("Disconnect") { error = Connection.setClaude(false, agents) }
                        } else {
                            Button("Connect") { error = Connection.setClaude(true, agents) }
                        }
                    }
                }
            } header: {
                Text("Connection")
            } footer: {
                Text("Islet adds hooks to ~/.claude/settings.json and keeps a backup next to it. Without Islet running, Claude Code works exactly as before.")
            }
        }
        .onAppear { agents.hooksInstalled = HookInstaller.isInstalled }
    }
}

private struct OutlookPane: View {
    @Environment(OutlookCalendar.self) private var calendar
    @AppStorage(Defaults.outlookEnabled) private var outlookEnabled = true
    @AppStorage(Defaults.meetingLead) private var meetingLead = 15
    var body: some View {
        Form {
            Section {
                Toggle("Show Outlook", isOn: $outlookEnabled)
                Picker("Show meetings from", selection: $meetingLead) {
                    ForEach([5, 10, 15, 30], id: \.self) { Text("\($0) min before").tag($0) }
                }
            }
            Section {
                LabeledContent("Status", value: Connection.outlook(calendar))
                if calendar.access != .granted {
                    LabeledContent("Calendar access") { Button("Allow", action: calendar.requestAccess) }
                }
                LabeledContent("Accounts") {
                    Button("Open Internet Accounts") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!)
                    }
                }
            } header: {
                Text("Connection")
            } footer: {
                Text("Islet reads Outlook through macOS Calendar. Add your Outlook or Exchange account in Internet Accounts; once it's there, only its calendars are shown.")
            }
        }
    }
}

private struct AboutPane: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                LabeledContent("Source") { Link("github.com/yahya-khamaisi/islet", destination: URL(string: "https://github.com/yahya-khamaisi/islet")!) }
            } footer: {
                Text("Islet keeps active apps beside the notch: Spotify, Outlook and Claude Code.")
            }
        }
    }
}
