import AppKit
import Observation

/// What Spotify is playing, read through its AppleScript dictionary. Spotify posts a
/// distributed notification on every change, so Islet never polls while nothing happens.
@Observable @MainActor
final class Spotify {
    static let bundleID = "com.spotify.client"

    struct Track: Equatable {
        var id: String
        var name: String
        var artist: String
        var album: String
        var duration: Double
    }

    private(set) var isRunning = false
    private(set) var track: Track?
    private(set) var isPlaying = false
    private(set) var shuffling = false
    private(set) var repeating = false
    private(set) var artwork: NSImage?
    /// Set when macOS refused Islet's Automation request.
    private(set) var isBlocked = false
    /// When music was last heard, so a paused track lingers for a while.
    private(set) var lastPlayed: Date?

    private var position: Double = 0
    private var positionStamp = Date.now
    private var artworkURL: String?
    private let queue = DispatchQueue(label: "islet.spotify")

    init() {
        DistributedNotificationCenter.default().addObserver(forName: .init("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard app?.bundleIdentifier == Spotify.bundleID else { return }
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        #if DEBUG
        // Demo mode never talks to the real Spotify.
        if CommandLine.arguments.contains("-demo") { artworkURL = "demo"; return }
        #endif
        refresh()
    }

    /// Playback position now, extrapolated between notifications.
    var currentPosition: Double {
        guard let track else { return 0 }
        let p = position + (isPlaying ? Date.now.timeIntervalSince(positionStamp) : 0)
        return min(max(p, 0), track.duration)
    }

    func togglePlay() {
        isPlaying.toggle()
        lastPlayed = .now
        positionStamp = .now
        send("playpause")
    }
    func next() { send("next track") }
    func previous() { send("previous track") }
    func toggleShuffle() { shuffling.toggle(); send("set shuffling to \(shuffling)") }
    func toggleRepeat() { repeating.toggle(); send("set repeating to \(repeating)") }
    func seek(to fraction: Double) {
        guard let track else { return }
        let target = track.duration * min(max(fraction, 0), 1)
        position = target
        positionStamp = .now
        send("set player position to \(target)")
    }

    /// Playing, or paused within the grace period you chose.
    var isActive: Bool {
        guard isRunning, track != nil else { return false }
        let grace = Double(UserDefaults.standard.integer(forKey: Defaults.pausedGrace)) * 60
        return isPlaying || (lastPlayed.map { Date.now.timeIntervalSince($0) < grace } ?? false)
    }

    func launch() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    /// Never `tell` Spotify unless it's running, or AppleScript would launch it.
    private var spotifyRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    private func send(_ command: String) {
        guard spotifyRunning, artworkURL != "demo" else { return }
        queue.async {
            _ = Self.run("tell application \"Spotify\" to \(command)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        if artworkURL == "demo" { return }
        guard spotifyRunning else {
            isRunning = false
            track = nil
            isPlaying = false
            artwork = nil
            artworkURL = nil
            return
        }
        isRunning = true
        queue.async { [weak self] in
            let result = Self.run(Self.stateScript)
            DispatchQueue.main.async { self?.apply(result) }
        }
    }

    private func apply(_ result: Result<String, ScriptError>) {
        switch result {
        case .failure(.denied):
            isBlocked = true
        case .failure:
            break
        case .success(let text):
            isBlocked = false
            let f = text.components(separatedBy: "\u{1F}")
            guard f.count >= 10 else { track = nil; return }
            isPlaying = f[0] == "playing"
            if isPlaying { lastPlayed = .now }
            track = f[4].isEmpty ? nil : Track(id: f[4], name: f[1], artist: f[2], album: f[3],
                                               duration: (Double(f[5]) ?? 0) / 1000)
            position = Double(f[6].replacingOccurrences(of: ",", with: ".")) ?? 0
            positionStamp = .now
            shuffling = f[8] == "true"
            repeating = f[9] == "true"
            loadArtwork(f[7])
        }
    }

    private func loadArtwork(_ link: String) {
        guard link != artworkURL else { return }
        artworkURL = link
        artwork = nil
        guard let url = URL(string: link) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url), link == artworkURL else { return }
            artwork = NSImage(data: data)
        }
    }

    #if DEBUG
    func loadDemo() {
        isRunning = true
        track = Track(id: "demo", name: "Midnight Drive", artist: "Lumen Coast", album: "Night Roads", duration: 206)
        isPlaying = true
        lastPlayed = .now
        position = 84
        positionStamp = .now
        shuffling = true
        artworkURL = "demo"
    }
    #endif

    // Fields are joined with the ASCII unit separator, which never appears in titles.
    private static let stateScript = """
    tell application "Spotify"
        set s to (ASCII character 31)
        set t to current track
        return (player state as string) & s & (name of t) & s & (artist of t) & s & (album of t) & s & (id of t) & s & (duration of t) & s & (player position) & s & (artwork url of t) & s & shuffling & s & repeating
    end tell
    """

    enum ScriptError: Error { case denied, failed }

    nonisolated private static func run(_ source: String) -> Result<String, ScriptError> {
        var error: NSDictionary?
        guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
            // -1743: the user turned off Islet's Automation access to Spotify.
            return (error?[NSAppleScript.errorNumber] as? Int) == -1743 ? .failure(.denied) : .failure(.failed)
        }
        return .success(output.stringValue ?? "")
    }
}
