import Foundation

/// Adds Islet's hooks to `~/.claude/settings.json`, and takes them out again. Every hook is
/// a `curl` to Islet's local server that stays silent and succeeds when Islet isn't
/// running, so Claude Code behaves exactly as before.
enum HookInstaller {
    static var settingsURL: URL {
        if let path = ProcessInfo.processInfo.environment["ISLET_CLAUDE_SETTINGS"] { return URL(fileURLWithPath: path) }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")
    }

    /// Hook events Islet listens to, with their matcher (tool events need one) and timeout.
    private static let events: [(name: String, matcher: String?, timeout: Int)] = [
        ("SessionStart", nil, 5),
        ("UserPromptSubmit", nil, 5),
        ("PreToolUse", "*", 5),
        ("PostToolUse", "*", 5),
        ("PermissionRequest", "*", 300),
        ("Notification", nil, 5),
        ("Stop", nil, 5),
        ("SessionEnd", nil, 5),
    ]

    static var token: String {
        if let token = UserDefaults.standard.string(forKey: Defaults.hookToken) { return token }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(token, forKey: Defaults.hookToken)
        return token
    }

    static var hookPath: String { "/hook/\(token)" }
    private static let marker = "127.0.0.1:\(AgentServer.port)/hook/"

    private static func command(timeout: Int) -> String {
        "curl -s -m \(timeout - 1) -X POST -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:\(AgentServer.port)\(hookPath) || true"
    }

    static var isInstalled: Bool {
        guard let data = try? Data(contentsOf: settingsURL), let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains(marker + token)
    }

    static func install() throws { try edit(adding: true) }
    static func uninstall() throws { try edit(adding: false) }

    private static func edit(adding: Bool) throws {
        let fm = FileManager.default
        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL) {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            settings = parsed
            // One backup, taken the first time Islet touches the file.
            let backup = settingsURL.appendingPathExtension("islet-backup")
            if !fm.fileExists(atPath: backup.path) { try data.write(to: backup) }
        } else {
            try fm.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = (hooks[event.name] as? [[String: Any]] ?? []).compactMap(removingIslet)
            if adding {
                var group: [String: Any] = ["hooks": [["type": "command", "command": command(timeout: event.timeout), "timeout": event.timeout]]]
                if let matcher = event.matcher { group["matcher"] = matcher }
                groups.append(group)
            }
            hooks[event.name] = groups.isEmpty ? nil : groups
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks

        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .withoutEscapingSlashes])
        try data.write(to: settingsURL, options: .atomic)
    }

    /// The group without Islet's handlers, or nil when nothing else is left in it.
    private static func removingIslet(_ group: [String: Any]) -> [String: Any]? {
        guard let handlers = group["hooks"] as? [[String: Any]] else { return group }
        let kept = handlers.filter { ($0["command"] as? String)?.contains(marker) != true }
        guard !kept.isEmpty else { return nil }
        var group = group
        group["hooks"] = kept
        return group
    }
}
