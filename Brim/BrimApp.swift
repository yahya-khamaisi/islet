import AppKit
import SwiftUI

@main
struct BrimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var app

    var body: some Scene {
        // A small menu-bar item, so Brim can always be reached even if the notch can't.
        MenuBarExtra("Brim", systemImage: "rectangle.topthird.inset.filled") {
            Button("Open Brim") { app.model.open(.tab(.home), pinned: true) }
            Button("Settings…") { app.model.open(.settings, pinned: true) }
                .keyboardShortcut(",")
            Divider()
            Button("Quit Brim") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = NotchModel()
    private var spotify: Spotify!
    private var calendar: OutlookCalendar!
    private var agents: AgentStore!
    private let server = AgentServer()
    private var controller: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Defaults.register()
        spotify = Spotify()
        calendar = OutlookCalendar()
        agents = AgentStore()

        let agents = agents!
        server.onRequest = { path, body, reply in
            MainActor.assumeIsolated {
                guard path == HookInstaller.hookPath else { return reply(AgentStore.noDecision) }
                agents.handle(body, reply: reply)
            }
        }
        do { try server.start() } catch { NSLog("Brim: agent server didn't start: \(error)") }

        controller = NotchController(model: model, content: NotchView()
            .environment(model)
            .environment(spotify)
            .environment(calendar)
            .environment(agents))
    }
}
