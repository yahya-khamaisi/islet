import SwiftUI

/// The island: the bare notch when nothing is active, a slot per active app beside it,
/// and one app's panel when you click or tap that slot.
struct IslandView: View {
    @Environment(IslandModel.self) private var model
    @Environment(Spotify.self) private var spotify
    @Environment(AgentStore.self) private var agents
    @Environment(OutlookCalendar.self) private var calendar
    @AppStorage(Defaults.enabled) private var enabled = true
    @AppStorage(Defaults.spotifyEnabled) private var spotifyEnabled = true
    @AppStorage(Defaults.claudeEnabled) private var claudeEnabled = true
    @AppStorage(Defaults.outlookEnabled) private var outlookEnabled = true
    @AppStorage(Defaults.expandForApprovals) private var expandForApprovals = true

    var body: some View {
        // Activity rules depend on time (paused music, meeting lead), so re-check every 15s.
        TimelineView(.periodic(from: .now, by: 15)) { _ in
            island
                .onChange(of: activeApps, initial: true) { _, apps in
                    model.leading = apps.filter { $0 == .spotify }
                    model.trailing = apps.filter { $0 != .spotify }
                }
        }
        .onChange(of: agents.waiting.first?.request?.id) { _, id in
            guard id != nil, expandForApprovals, let session = agents.waiting.first else { return }
            model.alert(session: session.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    private var activeApps: [IslandModel.App] {
        guard enabled else { return [] }
        var apps: [IslandModel.App] = []
        if spotifyEnabled, spotify.isActive { apps.append(.spotify) }
        if claudeEnabled, !agents.visible.isEmpty { apps.append(.claude) }
        if outlookEnabled, calendar.current != nil { apps.append(.outlook) }
        return apps
    }

    @ViewBuilder
    private var island: some View {
        let expanded = model.expansion != nil
        let idle = !expanded && model.leading.isEmpty && model.trailing.isEmpty
        let flare = expanded ? Metrics.panelFlare : idle ? 0 : Metrics.compactFlare
        Group {
            switch model.expansion {
            case nil: Compact()
            case .panel(.spotify): SpotifyPanel().frame(width: IslandModel.App.spotify.panelWidth)
            case .panel(.claude): ClaudePanel().frame(width: IslandModel.App.claude.panelWidth)
            case .panel(.outlook): OutlookPanel().frame(width: IslandModel.App.outlook.panelWidth)
            case .alert(let session): ApprovalAlert(sessionID: session).frame(width: 440)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
        .padding(.horizontal, flare)
        .background(.black)
        .clipShape(IslandShape(flare: flare, bottom: expanded ? Metrics.panelRadius : Metrics.compactRadius))
        .shadow(color: .black.opacity(expanded ? 0.5 : 0), radius: 24, y: 10)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { model.drawnSize = $0 }
    }
}

// MARK: Compact

/// The notch with active apps beside it. Both sides share one width, so the hardware
/// notch stays centred however many apps are showing.
private struct Compact: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let count = max(model.leading.count, model.trailing.count)
        let side = count == 0 ? 0 : CGFloat(count) * Metrics.slot + Metrics.slotInset
        HStack(spacing: 0) {
            HStack(spacing: 0) { ForEach(model.leading.reversed()) { Slot(app: $0) } }
                .frame(width: side, alignment: .trailing)
            Color.clear.frame(width: model.notchSize.width)
            HStack(spacing: 0) { ForEach(model.trailing) { Slot(app: $0) } }
                .frame(width: side, alignment: .leading)
        }
        .frame(height: model.notchSize.height)
    }
}

private struct Slot: View {
    @Environment(IslandModel.self) private var model
    @Environment(Spotify.self) private var spotify
    @Environment(AgentStore.self) private var agents
    @Environment(OutlookCalendar.self) private var calendar
    let app: IslandModel.App

    var body: some View {
        let hovered = model.hovered == app
        Button { model.toggle(app) } label: {
            icon
                .scaleEffect(hovered ? 1.12 : 1)
                .frame(width: Metrics.slot, height: model.notchSize.height)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white.opacity(hovered ? 0.12 : 0))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 3)
                }
                .overlay(alignment: .topTrailing) { badge.offset(x: -2, y: 3) }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(app.name)
        .accessibilityLabel(app.name)
    }

    @ViewBuilder private var icon: some View {
        if app == .spotify {
            Artwork(image: spotify.artwork, size: Metrics.slotIcon, radius: 6)
                .opacity(spotify.isPlaying ? 1 : 0.5)
        } else if app == .outlook, let meeting = calendar.current {
            // The countdown is the icon: minutes to go, or a camera once it has started.
            let minutes = Int(meeting.start.timeIntervalSinceNow / 60)
            Group {
                if minutes <= 0 { Image(systemName: "video.fill").font(.system(size: 9, weight: .bold)) }
                else { Text("\(minutes)").font(.system(size: 10, weight: .bold).monospacedDigit()) }
            }
            .foregroundStyle(.white)
            .frame(width: Metrics.slotIcon, height: Metrics.slotIcon)
            .background(Palette.outlook, in: .rect(cornerRadius: 6, style: .continuous))
        } else {
            AppGlyph(app: app)
        }
    }

    @ViewBuilder private var badge: some View {
        switch app {
        case .claude:
            if !agents.waiting.isEmpty {
                Badge(text: "!", fill: Palette.attention, ink: .black)
            } else if agents.runningCount > 0 {
                Badge(text: "\(agents.runningCount)", fill: Color(white: 0.24), ink: .white)
            } else {
                Badge(text: "✓", fill: Palette.done, ink: .black)
            }
        case .outlook, .spotify:
            EmptyView()
        }
    }
}

private struct Badge: View {
    let text: String
    let fill: Color
    let ink: Color
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold).monospacedDigit())
            .foregroundStyle(ink)
            .padding(.horizontal, 3)
            .frame(minWidth: 12, minHeight: 12)
            .background(fill, in: .capsule)
            .overlay { Capsule().strokeBorder(.black, lineWidth: 1.5) }
    }
}

// MARK: Approval alert

/// Shown on its own when an agent asks for permission; a click on the text opens the
/// full Claude Code panel.
private struct ApprovalAlert: View {
    @Environment(IslandModel.self) private var model
    @Environment(AgentStore.self) private var agents
    let sessionID: String

    var body: some View {
        let session = agents.sessions[sessionID]
        VStack(spacing: 0) {
            Color.clear.frame(height: model.notchSize.height)
            HStack(spacing: 12) {
                AppGlyph(app: .claude, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(session?.project ?? "Claude Code") needs you").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(session?.request?.detail ?? session?.activity ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { model.open(.claude) }
                if session?.request?.answerable == true {
                    Button("Deny") { agents.answer(.deny, for: sessionID); model.close() }.buttonStyle(PillStyle())
                    Button("Allow") { agents.answer(.allow, for: sessionID); model.close() }.buttonStyle(PillStyle(fill: Palette.action))
                } else {
                    Button("Open") { model.open(.claude) }.buttonStyle(PillStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .onChange(of: session?.status) { _, status in
            if status != .waiting { model.close() }
        }
    }
}
