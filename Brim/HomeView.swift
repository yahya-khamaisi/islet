import SwiftUI

/// Three cards of one height: what's playing, what's next, what your agents are doing.
struct HomeView: View {
    var body: some View {
        HStack(spacing: Metrics.gap) {
            SpotifyCard()
            MeetingCard()
            AgentsCard()
        }
        .frame(height: Metrics.cardHeight)
    }
}

// MARK: Spotify

private struct SpotifyCard: View {
    @Environment(Spotify.self) private var spotify

    var body: some View {
        Card {
            CardLabel(symbol: "music.note", tint: Palette.spotify, title: "Spotify")
            if spotify.isBlocked {
                CardPrompt(text: "Brim can't see Spotify. Turn Brim on under Automation in Privacy & Security.", action: "Open settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
                }
            } else if !spotify.isRunning {
                CardPrompt(text: "Spotify isn't open.", action: "Open Spotify") { spotify.launch() }
            } else if let track = spotify.track {
                HStack(spacing: 12) {
                    Artwork(image: spotify.artwork, size: 56, radius: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(track.artist).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 12)
                Progress(duration: track.duration)
                    .padding(.bottom, 10)
                Controls()
            } else {
                Text("Nothing playing").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                Spacer()
                Controls()
            }
        }
    }
}

/// Elapsed and remaining time; click anywhere on the bar to jump there.
private struct Progress: View {
    @Environment(Spotify.self) private var spotify
    let duration: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let position = spotify.currentPosition
            let fraction = duration > 0 ? position / duration : 0
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule().fill(.white).frame(width: geo.size.width * fraction)
                    }
                    .frame(height: 3)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .onTapGesture { location in spotify.seek(to: location.x / geo.size.width) }
                }
                .frame(height: 10)
                HStack {
                    Text(Self.time(position))
                    Spacer()
                    Text("-" + Self.time(duration - position))
                }
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(Palette.secondary)
            }
        }
    }

    private static func time(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct Controls: View {
    @Environment(Spotify.self) private var spotify

    var body: some View {
        HStack {
            Button(action: spotify.toggleShuffle) { Image(systemName: "shuffle") }
                .buttonStyle(IconStyle(size: 26, filled: false))
                .foregroundStyle(spotify.shuffling ? Palette.spotify : Palette.secondary)
                .accessibilityLabel("Shuffle")
            Spacer()
            Button(action: spotify.previous) { Image(systemName: "backward.fill") }
                .buttonStyle(IconStyle(size: 30, filled: false))
                .accessibilityLabel("Previous")
            Spacer()
            Button(action: spotify.togglePlay) { Image(systemName: spotify.isPlaying ? "pause.fill" : "play.fill") }
                .buttonStyle(IconStyle(size: 36))
                .accessibilityLabel(spotify.isPlaying ? "Pause" : "Play")
            Spacer()
            Button(action: spotify.next) { Image(systemName: "forward.fill") }
                .buttonStyle(IconStyle(size: 30, filled: false))
                .accessibilityLabel("Next")
            Spacer()
            Button(action: spotify.toggleRepeat) { Image(systemName: "repeat") }
                .buttonStyle(IconStyle(size: 26, filled: false))
                .foregroundStyle(spotify.repeating ? Palette.spotify : Palette.secondary)
                .accessibilityLabel("Repeat")
        }
    }
}

// MARK: Outlook

private struct MeetingCard: View {
    @Environment(OutlookCalendar.self) private var calendar

    var body: some View {
        Card {
            CardLabel(symbol: "calendar", tint: Palette.outlook, title: calendar.usesOutlookAccount ? "Outlook · Today" : "Calendar · Today")
            switch calendar.access {
            case .notAsked:
                CardPrompt(text: "See your Outlook meetings and join them from here.", action: "Allow calendar access", run: calendar.requestAccess)
            case .denied:
                CardPrompt(text: "Calendar access is off for Brim.", action: "Open settings", run: calendar.requestAccess)
            case .granted:
                let upcoming = calendar.upcomingToday
                if let next = upcoming.first {
                    NextMeeting(meeting: next)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(upcoming.dropFirst().prefix(2)) { meeting in
                            HStack(spacing: 8) {
                                Dot(color: meeting.color)
                                Text(meeting.start, format: .dateTime.hour().minute()).foregroundStyle(Palette.secondary)
                                Text(meeting.title).lineLimit(1)
                            }
                            .font(.system(size: 12))
                        }
                    }
                    .padding(.top, 10)
                    Spacer(minLength: 8)
                    if let url = next.joinURL {
                        Button { NSWorkspace.shared.open(url) } label: { Label("Join", systemImage: "video.fill") }
                            .buttonStyle(PillStyle(fill: Palette.outlook, stretch: true))
                    } else {
                        Button("Open Outlook", action: calendar.openOutlook).buttonStyle(PillStyle(stretch: true))
                    }
                } else {
                    CardPrompt(text: "No more meetings today.", action: "Open Outlook", run: calendar.openOutlook)
                }
            }
        }
    }
}

private struct NextMeeting: View {
    let meeting: OutlookCalendar.Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(when).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.outlook)
            Text(meeting.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text(detail).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.outlook.opacity(0.16), in: .rect(cornerRadius: 12, style: .continuous))
    }

    private var when: String {
        let minutes = Int(meeting.start.timeIntervalSinceNow / 60)
        if minutes <= 0 { return "Now · ends in \(Int(meeting.end.timeIntervalSinceNow / 60) + 1) min" }
        if minutes < 60 { return "In \(minutes) min" }
        return "At " + meeting.start.formatted(date: .omitted, time: .shortened)
    }

    private var detail: String {
        let range = meeting.start.formatted(date: .omitted, time: .shortened) + " – " + meeting.end.formatted(date: .omitted, time: .shortened)
        return meeting.place.isEmpty ? range : range + " · " + meeting.place
    }
}

// MARK: Claude Code

private struct AgentsCard: View {
    @Environment(NotchModel.self) private var model
    @Environment(AgentStore.self) private var agents

    var body: some View {
        let sessions = agents.ordered
        Card {
            CardLabel(symbol: "sparkle", tint: Palette.claude,
                      title: sessions.isEmpty ? "Claude Code" : "Claude Code · \(sessions.count) session\(sessions.count == 1 ? "" : "s")")
            if !agents.hooksInstalled && sessions.isEmpty {
                CardPrompt(text: "Connect Claude Code to follow your sessions and approve requests here.", action: "Connect") {
                    model.show(.settings)
                }
            } else if sessions.isEmpty {
                CardPrompt(text: "No sessions yet. Start one in Claude and it shows up here.", action: "Open Claude", run: AgentStore.activateClaude)
            } else {
                TimelineView(.everyMinute) { _ in
                    VStack(spacing: 4) {
                        ForEach(sessions.prefix(4)) { session in
                            HStack(spacing: 8) {
                                Dot(color: session.status.color, pulsing: session.status == .waiting)
                                Text(session.project).font(.system(size: 12)).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(trailing(session))
                                    .font(.system(size: 11))
                                    .foregroundStyle(session.status == .waiting ? Palette.attention : Palette.secondary)
                            }
                            .frame(height: 24)
                        }
                    }
                }
                Spacer(minLength: 8)
                let waiting = agents.waiting.count
                Button(waiting > 0 ? "Review \(waiting) request\(waiting == 1 ? "" : "s")" : "View all") { model.show(.tab(.agents)) }
                    .buttonStyle(PillStyle(stretch: true))
            }
        }
    }

    private func trailing(_ session: AgentStore.Session) -> String {
        switch session.status {
        case .waiting: "Needs you"
        case .running: session.turnStarted.elapsed()
        case .done: "Done"
        case .idle: "Idle"
        }
    }
}
