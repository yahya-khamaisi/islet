import AppKit
import Observation
import SwiftUI

/// Claude Code sessions as reported by their hooks: what each is doing, and any
/// permission request waiting on you.
@Observable @MainActor
final class AgentStore {
    enum Status { case running, waiting, idle, done }

    struct Request: Equatable {
        let id = UUID()
        let tool: String
        let detail: String
        let since = Date.now
        /// False once Islet stopped holding it and handed it back to Claude.
        var answerable = true
    }

    struct Session: Identifiable, Equatable {
        let id: String
        var project: String
        var status: Status = .idle
        var activity = "Ready"
        var turnStarted = Date.now
        var updated = Date.now
        var request: Request?
    }

    private(set) var sessions: [String: Session] = [:]
    /// Whether Islet's hooks are in Claude Code's settings; Settings refreshes it.
    var hooksInstalled = HookInstaller.isInstalled
    private var replies: [UUID: @Sendable (Data) -> Void] = [:]
    private var pruner: Timer?
    private var shortcuts: [HotKey] = []

    init() {
        pruner = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.prune() }
        }
    }

    /// Requests first, then running, then the rest, newest first within each.
    var ordered: [Session] {
        sessions.values.sorted {
            let rank: (Session) -> Int = { $0.status == .waiting ? 0 : $0.status == .running ? 1 : 2 }
            return rank($0) != rank($1) ? rank($0) < rank($1) : $0.updated > $1.updated
        }
    }
    var waiting: [Session] { ordered.filter { $0.status == .waiting } }
    var runningCount: Int { sessions.values.filter { $0.status == .running }.count }

    /// Sessions worth a slot beside the notch: anything running or waiting, plus finished
    /// and idle ones for the time you chose.
    var visible: [Session] {
        let window = Double(UserDefaults.standard.integer(forKey: Defaults.finishedVisible)) * 60
        return ordered.filter { $0.status == .running || $0.status == .waiting || Date.now.timeIntervalSince($0.updated) < window }
    }

    // MARK: Hook events

    func handle(_ body: Data, reply: @escaping @Sendable (Data) -> Void) {
        guard let event = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let name = event["hook_event_name"] as? String,
              let id = event["session_id"] as? String else { return reply(Self.noDecision) }
        let cwd = event["cwd"] as? String ?? ""
        var session = sessions[id] ?? Session(id: id, project: Self.project(from: cwd))
        if !cwd.isEmpty { session.project = Self.project(from: cwd) }
        session.updated = .now
        let tool = event["tool_name"] as? String ?? ""
        let input = event["tool_input"] as? [String: Any] ?? [:]

        switch name {
        case "SessionEnd":
            sessions[id] = nil
            return reply(Self.noDecision)
        case "UserPromptSubmit":
            session.status = .running
            session.activity = "Thinking…"
            session.turnStarted = .now
            session.request = nil
        case "PreToolUse":
            session.status = .running
            session.activity = Self.describe(tool: tool, input: input)
            session.request = nil
        case "PostToolUse", "PostToolUseFailure":
            if session.status != .running { session.status = .running }
            session.request = nil
        case "PermissionRequest":
            let request = Request(tool: tool, detail: Self.detail(tool: tool, input: input))
            session.status = .waiting
            session.activity = "Wants to \(Self.verb(for: tool))"
            session.request = request
            sessions[id] = session
            replies[request.id] = reply
            holdUntilTimeout(request.id, session: id)
            syncShortcuts()
            return
        case "Notification":
            let message = (event["message"] as? String ?? "").lowercased()
            let kind = event["notification_type"] as? String ?? ""
            if kind == "permission_prompt" || message.contains("permission") {
                if session.request == nil { session.status = .waiting; session.activity = "Needs your approval" }
            } else if kind == "idle_prompt" || message.contains("waiting for your input") {
                session.status = .idle
                session.activity = "Waiting for your reply"
            }
        case "Stop":
            session.status = .done
            session.activity = "Finished"
            session.request = nil
        default:
            break
        }
        sessions[id] = session
        reply(Self.noDecision)
        syncShortcuts()
    }

    // MARK: Answers

    enum Answer { case allow, deny, handBack }

    func answer(_ answer: Answer, for sessionID: String) {
        guard var session = sessions[sessionID], let request = session.request else { return }
        if let reply = replies.removeValue(forKey: request.id) {
            switch answer {
            case .allow: reply(Self.decision("allow"))
            case .deny: reply(Self.decision("deny", message: "Denied from Islet."))
            case .handBack: reply(Self.noDecision)
            }
        }
        if answer == .handBack {
            session.request?.answerable = false
            Self.activateClaude()
        } else {
            session.request = nil
            session.status = .running
            session.activity = answer == .allow ? "Approved" : "Denied"
        }
        sessions[sessionID] = session
        syncShortcuts()
    }

    /// ⌃⌘Y allows and ⌃⌘N denies the newest answerable request. They're registered only
    /// while one is waiting, so the keys stay free for other apps the rest of the time.
    func syncShortcuts() {
        let target = ordered.first { $0.request?.answerable == true }?.id
        guard let target, UserDefaults.standard.bool(forKey: Defaults.approvalShortcuts) else { shortcuts = []; return }
        shortcuts = [
            HotKey(.allow, id: 1) { [weak self] in self?.answer(.allow, for: target) },
            HotKey(.deny, id: 2) { [weak self] in self?.answer(.deny, for: target) },
        ]
    }

    /// Claude waits on the hook, so Islet never holds a request longer than you chose; after
    /// that the request goes back to Claude's own prompt.
    private func holdUntilTimeout(_ requestID: UUID, session: String) {
        let wait = max(10, UserDefaults.standard.integer(forKey: Defaults.approvalWait))
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(wait)) { [weak self] in
            guard let self, let reply = self.replies.removeValue(forKey: requestID) else { return }
            reply(Self.noDecision)
            if self.sessions[session]?.request?.id == requestID { self.sessions[session]?.request?.answerable = false }
            self.syncShortcuts()
        }
    }

    private func prune() {
        let cutoff = Date.now.addingTimeInterval(-2 * 3600)
        sessions = sessions.filter { $0.value.updated > cutoff || $0.value.status == .waiting }
    }

    #if DEBUG
    func loadDemo() {
        let now = Date.now
        sessions = [
            "a": Session(id: "a", project: "islet", status: .waiting, activity: "Wants to run a command", turnStarted: now.addingTimeInterval(-120), updated: now,
                         request: Request(tool: "Bash", detail: "xcodebuild -scheme Islet -configuration Debug build")),
            "b": Session(id: "b", project: "telegram_tv", status: .running, activity: "Editing PlayerView.swift", turnStarted: now.addingTimeInterval(-360), updated: now),
            "c": Session(id: "c", project: "vitals", status: .running, activity: "Running tests · 42 of 118", turnStarted: now.addingTimeInterval(-660), updated: now),
            "d": Session(id: "d", project: "kynly", status: .done, activity: "Opened a pull request", turnStarted: now.addingTimeInterval(-1500), updated: now.addingTimeInterval(-1080)),
        ]
    }
    #endif

    static func activateClaude() {
        let claude = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier?.hasPrefix("com.anthropic") == true }
        claude?.activate()
    }

    // MARK: Replies

    nonisolated static let noDecision = Data("{}".utf8)

    nonisolated private static func decision(_ behavior: String, message: String? = nil) -> Data {
        var decision: [String: Any] = ["behavior": behavior]
        if let message { decision["message"] = message }
        let output: [String: Any] = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision]]
        return (try? JSONSerialization.data(withJSONObject: output)) ?? noDecision
    }

    // MARK: Describing tools

    private static func project(from cwd: String) -> String {
        cwd.isEmpty ? "Claude Code" : URL(fileURLWithPath: cwd).lastPathComponent
    }

    private static func file(_ input: [String: Any]) -> String {
        ((input["file_path"] ?? input["notebook_path"] ?? input["path"]) as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "a file"
    }

    static func describe(tool: String, input: [String: Any]) -> String {
        switch tool {
        case "Bash":
            if let d = input["description"] as? String, !d.isEmpty { return d }
            return "Running " + ((input["command"] as? String)?.components(separatedBy: "\n").first ?? "a command")
        case "Edit", "MultiEdit", "Write", "NotebookEdit": return "Editing \(file(input))"
        case "Read": return "Reading \(file(input))"
        case "Grep", "Glob": return "Searching the code"
        case "WebFetch", "WebSearch": return "Reading the web"
        case "Task", "Agent": return "Running a subagent"
        case "TodoWrite": return "Updating its plan"
        default:
            if tool.hasPrefix("mcp__") { return "Using " + (tool.components(separatedBy: "__").dropFirst().first ?? "a tool") }
            return "Using \(tool)"
        }
    }

    private static func verb(for tool: String) -> String {
        switch tool {
        case "Bash": "run a command"
        case "Edit", "MultiEdit", "Write", "NotebookEdit": "edit a file"
        case "WebFetch", "WebSearch": "use the web"
        default: "use \(tool.hasPrefix("mcp__") ? tool.components(separatedBy: "__").dropFirst().first ?? tool : tool)"
        }
    }

    private static func detail(tool: String, input: [String: Any]) -> String {
        if let command = input["command"] as? String { return command }
        if let path = (input["file_path"] ?? input["notebook_path"]) as? String { return path }
        if let url = input["url"] as? String { return url }
        let data = (try? JSONSerialization.data(withJSONObject: input, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(data: data, encoding: .utf8) ?? tool
    }
}

extension AgentStore.Status {
    var color: Color {
        switch self {
        case .running: Palette.claude
        case .waiting: Palette.attention
        case .idle: Palette.secondary
        case .done: Palette.done
        }
    }
    var label: String {
        switch self {
        case .running: "Running"
        case .waiting: "Needs you"
        case .idle: "Idle"
        case .done: "Done"
        }
    }
}
