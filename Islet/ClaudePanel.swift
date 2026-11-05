import SwiftUI

/// The request that needs you first, then every other session.
struct ClaudePanel: View {
    @Environment(IslandModel.self) private var model
    @Environment(AgentStore.self) private var agents

    var body: some View {
        let waiting = agents.waiting
        let others = agents.visible.filter { $0.status != .waiting }
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: model.notchSize.height)
            PanelHeader(title: "Claude Code", subtitle: summary, close: model.close) {
                AppGlyph(app: .claude, size: 44)
            }
            if agents.sessions.isEmpty {
                PanelPrompt(text: "No sessions yet. Sessions in the Claude app and the terminal show up here as they run.",
                            action: "Open Claude", run: AgentStore.activateClaude)
            }
            if let first = waiting.first {
                RequestCard(session: first)
                HStack {
                    if waiting.count > 1 {
                        Text("\(waiting.count - 1) more waiting").foregroundStyle(Palette.attention)
                    }
                    Spacer()
                    if first.request?.answerable == true, UserDefaults.standard.bool(forKey: Defaults.approvalShortcuts) {
                        Text("\(Shortcut.allow.display) allows · \(Shortcut.deny.display) denies").foregroundStyle(.white.opacity(0.35))
                    }
                }
                .font(.system(size: 11))
                .padding(.top, 8)
            }
            TimelineView(.everyMinute) { _ in
                VStack(spacing: 0) {
                    ForEach(Array(others.prefix(4).enumerated()), id: \.element.id) { index, session in
                        if index > 0 || !waiting.isEmpty { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
                        SessionRow(session: session)
                    }
                }
            }
            .padding(.top, waiting.isEmpty ? 0 : 8)
        }
        .padding([.horizontal, .bottom], Metrics.panelPadding)
    }

    private var summary: String {
        var parts: [String] = []
        if agents.runningCount > 0 { parts.append("\(agents.runningCount) running") }
        if !agents.waiting.isEmpty { parts.append("\(agents.waiting.count) need\(agents.waiting.count == 1 ? "s" : "") you") }
        return parts.isEmpty ? "All quiet" : parts.joined(separator: " · ")
    }
}

private struct RequestCard: View {
    @Environment(AgentStore.self) private var agents
    let session: AgentStore.Session

    var body: some View {
        let request = session.request
        Card(outline: Palette.attention.opacity(0.5)) {
            HStack(spacing: 10) {
                Dot(color: Palette.attention, pulsing: true)
                Text(session.project).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 8)
                Text(session.activity.lowercased()).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
            }
            if let detail = request?.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 9, style: .continuous))
                    .padding(.top, 10)
            }
            HStack(spacing: 8) {
                if request?.answerable == true {
                    Spacer()
                    Button("Answer in Claude") { agents.answer(.handBack, for: session.id) }.buttonStyle(PillStyle())
                    Button("Deny") { agents.answer(.deny, for: session.id) }.buttonStyle(PillStyle())
                    Button("Allow once") { agents.answer(.allow, for: session.id) }.buttonStyle(PillStyle(fill: Palette.action))
                } else {
                    Text("Waiting for you in Claude").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    Spacer()
                    Button("Open Claude", action: AgentStore.activateClaude).buttonStyle(PillStyle(fill: Palette.action))
                }
            }
            .padding(.top, 10)
        }
    }
}

private struct SessionRow: View {
    let session: AgentStore.Session

    var body: some View {
        Button(action: AgentStore.activateClaude) {
            HStack(spacing: 10) {
                Dot(color: session.status.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.project).font(.system(size: 13)).lineLimit(1)
                    Text(session.activity).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
                }
                Spacer(minLength: 12)
                Text(session.status == .running ? session.turnStarted.elapsed() : "\(session.status.label) · \(session.updated.elapsed())")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Palette.secondary)
            }
            .frame(height: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
