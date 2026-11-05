import AppKit
import SwiftUI

@main
struct IsletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var app

    var body: some Scene {
        MenuBarExtra("Islet", systemImage: "capsule.fill") {
            app.inject(MenuPanel())
        }
        .menuBarExtraStyle(.window)

        Window("Islet Settings", id: "settings") {
            app.inject(AdvancedSettings())
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = IslandModel()
    let spotify = Spotify()
    let calendar = OutlookCalendar()
    let agents = AgentStore()
    private let server = AgentServer()
    private var controller: IslandController?

    override init() {
        Defaults.register()
        super.init()
    }

    /// Gives a view every store it might read.
    func inject<V: View>(_ view: V) -> some View {
        view.environment(model).environment(spotify).environment(calendar).environment(agents)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let agents = agents
        server.onRequest = { path, body, reply in
            MainActor.assumeIsolated {
                guard path == HookInstaller.hookPath else { return reply(AgentStore.noDecision) }
                agents.handle(body, reply: reply)
            }
        }
        do { try server.start() } catch { NSLog("Islet: agent server didn't start: \(error)") }

        controller = IslandController(model: model, content: inject(IslandView()))
        #if DEBUG
        Demo.runIfRequested(self)
        #endif
    }
}

#if DEBUG
/// `-demo [spotify|claude|outlook|alert|menu|settings]` fills Islet with sample data and
/// opens one state, so every screen can be captured for design review.
@MainActor
enum Demo {
    private static var windows: [NSWindow] = []

    static func runIfRequested(_ app: AppDelegate) {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-demo") else { return }
        app.spotify.loadDemo()
        app.agents.loadDemo()
        app.calendar.loadDemo()
        let state = i + 1 < args.count ? args[i + 1] : ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch state {
            case "spotify": app.model.open(.spotify)
            case "claude": app.model.open(.claude)
            case "outlook": app.model.open(.outlook)
            case "alert": app.model.alert(session: "a")
            case "menu": show(app.inject(MenuPanel()), title: "Islet", panel: true)
            case "settings": show(app.inject(AdvancedSettings(pane: .claude)), title: "Islet Settings", panel: false)
            default: break
            }
        }
    }

    private static func show<V: View>(_ view: V, title: String, panel: Bool) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = title
        if panel { window.styleMask = [.titled, .fullSizeContentView]; window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden }
        window.setContentSize(window.contentViewController!.view.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        windows.append(window)
    }
}
#endif
