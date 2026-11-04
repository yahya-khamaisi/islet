import SwiftUI

/// Requests that need you, pinned on top, then every other session.
struct AgentsView: View {
    @Environment(NotchModel.self) private var model
    @Environment(AgentStore.self) private var agents

    var body: some View {
        let others = agents.ordered.filter { $0.status != .waiting }
        VStack(spacing: Metrics.gap) {
            if agents.sessions.isEmpty {
                Card(fills: false) {
                    CardLabel(symbol: "sparkle", tint: Palette.claude, title: "Claude Code")
                    if agents.hooksInstalled {
                        CardPrompt(text: "No sessions yet. Sessions in the Claude app and the terminal show up here as they run.",
                                   action: "Open Claude", run: AgentStore.activateClaude)
                    } else {
                        CardPrompt(text: "Connect Claude Code to follow your sessions and approve requests here.", action: "Connect") {
                            model.show(.settings)
                        }
                    }
                }
                .frame(height: 120)
            }
            ForEach(agents.waiting.prefix(2)) { RequestCard(session: $0) }
            if !others.isEmpty {
                TimelineView(.everyMinute) { _ in
                    VStack(spacing: 0) {
                        ForEach(Array(others.prefix(agents.waiting.isEmpty ? 5 : 3).enumerated()), id: \.element.id) { index, session in
                            if index > 0 { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
                            SessionRow(session: session)
                        }
                    }
                    .background(Palette.fill, in: .rect(cornerRadius: Metrics.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5)
                    }
                }
            }
        }
    }
}

private struct RequestCard: View {
    @Environment(AgentStore.self) private var agents
    let session: AgentStore.Session

    var body: some View {
        if let request = session.request ?? fallback {
            Card(outline: Palette.attention.opacity(0.45), fills: false) {
                HStack(spacing: 10) {
                    Dot(color: Palette.attention, pulsing: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.project).font(.system(size: 13, weight: .semibold))
                        Text("\(session.activity) · \(request.since.elapsed())").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Text("Needs you").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.attention)
                }
                if !request.detail.isEmpty {
                    Text(request.detail)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(3)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.5), in: .rect(cornerRadius: 10, style: .continuous))
                        .padding(.top, 12)
                }
                HStack(spacing: Metrics.gap) {
                    if request.answerable {
                        Spacer()
                        Button("Deny") { agents.answer(.deny, for: session.id) }.buttonStyle(PillStyle())
                        Button("Answer in Claude") { agents.answer(.handBack, for: session.id) }.buttonStyle(PillStyle())
                        Button("Allow once") { agents.answer(.allow, for: session.id) }.buttonStyle(PillStyle(fill: Palette.action))
                    } else {
                        Text("Waiting for you in Claude").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                        Spacer()
                        Button("Open Claude", action: AgentStore.activateClaude).buttonStyle(PillStyle(fill: Palette.action))
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    /// A permission prompt Brim heard about only through a notification.
    private var fallback: AgentStore.Request? {
        var request = AgentStore.Request(tool: "", detail: "")
        request.answerable = false
        return request
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
                Text("\(session.status.label) · \((session.status == .running ? session.turnStarted : session.updated).elapsed())")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.secondary)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, Metrics.cardPadding)
            .frame(height: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
