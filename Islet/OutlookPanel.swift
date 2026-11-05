import SwiftUI

/// The next meeting as the hero with Join as its one action, then the rest of today.
struct OutlookPanel: View {
    @Environment(IslandModel.self) private var model
    @Environment(OutlookCalendar.self) private var calendar

    var body: some View {
        let upcoming = calendar.upcomingToday
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: model.notchSize.height)
            PanelHeader(title: calendar.usesOutlookAccount ? "Outlook" : "Calendar",
                        subtitle: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                        close: model.close) {
                AppGlyph(app: .outlook, size: 44)
            }
            if let next = upcoming.first {
                TimelineView(.everyMinute) { _ in Hero(meeting: next) }
                ForEach(upcoming.dropFirst().prefix(3)) { meeting in
                    HStack(spacing: 12) {
                        Text(meeting.start.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(Palette.secondary)
                            .frame(width: 48, alignment: .leading)
                        RoundedRectangle(cornerRadius: 2).fill(meeting.color).frame(width: 3, height: 20)
                        Text(meeting.title).font(.system(size: 12)).lineLimit(1)
                        Spacer(minLength: 0)
                        if !meeting.place.isEmpty {
                            Text(meeting.place).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
                        }
                    }
                    .frame(height: 36)
                }
                .padding(.top, 6)
            } else {
                PanelPrompt(text: "No more meetings today.", action: "Open Outlook", run: calendar.openOutlook)
            }
        }
        .padding([.horizontal, .bottom], Metrics.panelPadding)
    }
}

private struct Hero: View {
    let meeting: OutlookCalendar.Meeting

    var body: some View {
        Card(tint: Palette.outlook.opacity(0.16)) {
            Text(when).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.outlook)
            Text(meeting.title).font(.system(size: 15, weight: .semibold)).lineLimit(1).padding(.top, 2)
            Text(detail).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1).padding(.top, 2)
            if let url = meeting.joinURL {
                Button { NSWorkspace.shared.open(url) } label: { Label("Join", systemImage: "video.fill") }
                    .buttonStyle(PillStyle(fill: Palette.outlook, stretch: true))
                    .padding(.top, 12)
            }
        }
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
