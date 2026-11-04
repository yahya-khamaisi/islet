import SwiftUI

/// This month on the left, the chosen day's meetings on the right.
struct CalendarView: View {
    @Environment(OutlookCalendar.self) private var calendar
    @State private var day = Date.now

    var body: some View {
        Group {
            if calendar.access == .granted {
                HStack(spacing: Metrics.gap) {
                    Card { MonthGrid(day: $day) }
                        .frame(width: 232)
                    Card(padding: 0) { DayList(day: day) }
                }
            } else {
                Card {
                    CardLabel(symbol: "calendar", tint: Palette.outlook, title: "Outlook")
                    CardPrompt(text: "Islet reads Outlook through macOS Calendar. Allow access, and add your Outlook account in System Settings › Internet Accounts if it isn't there yet.",
                               action: "Allow calendar access", run: calendar.requestAccess)
                }
            }
        }
        .frame(height: Metrics.cardHeight)
    }
}

private struct MonthGrid: View {
    @Environment(OutlookCalendar.self) private var calendar
    @Binding var day: Date

    var body: some View {
        let cal = Calendar.current
        let start = calendar.month.start
        let count = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let offset = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        let busy = Set(calendar.meetings.map { cal.component(.day, from: $0.start) })
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let weekdays = (0..<7).map { symbols[($0 + cal.firstWeekday - 1) % 7] }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        CardLabel(symbol: "calendar", tint: Palette.outlook, title: start.formatted(.dateTime.month(.wide).year()))
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, symbol in
                Text(symbol).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.4)).frame(height: 18)
            }
            ForEach(0..<(offset + count), id: \.self) { index in
                if index < offset {
                    Color.clear.frame(height: 20)
                } else {
                    let number = index - offset + 1
                    let date = cal.date(byAdding: .day, value: number - 1, to: start)!
                    let selected = cal.isDate(date, inSameDayAs: day)
                    let today = cal.isDateInToday(date)
                    Button { day = date } label: {
                        Text("\(number)")
                            .font(.system(size: 11, weight: today ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(selected ? .white : .white.opacity(0.8))
                            .frame(width: 22, height: 20)
                            .background { if selected { Capsule().fill(Palette.outlook) } else if today { Capsule().strokeBorder(Palette.outlook, lineWidth: 1) } }
                            .overlay(alignment: .bottom) {
                                if busy.contains(number), !selected { Circle().fill(Palette.outlook).frame(width: 3, height: 3).offset(y: 2) }
                            }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DayList: View {
    @Environment(OutlookCalendar.self) private var calendar
    let day: Date

    var body: some View {
        let meetings = calendar.meetings(on: day)
        HStack {
            CardLabel(symbol: "list.bullet", tint: Palette.outlook,
                      title: Calendar.current.isDateInToday(day) ? "Today" : day.formatted(.dateTime.weekday(.wide).day().month()))
            Spacer()
            Button("Open Outlook", action: calendar.openOutlook)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.outlook)
                .padding(.bottom, 10)
        }
        .padding([.horizontal, .top], Metrics.cardPadding)

        if meetings.isEmpty {
            Text("No meetings.").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                .padding(.horizontal, Metrics.cardPadding)
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(meetings.enumerated()), id: \.element.id) { index, meeting in
                        if index > 0 { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
                        MeetingRow(meeting: meeting)
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

private struct MeetingRow: View {
    let meeting: OutlookCalendar.Meeting

    var body: some View {
        let past = meeting.end < .now
        HStack(spacing: 12) {
            Text(meeting.isAllDay ? "All day" : meeting.start.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Palette.secondary)
                .frame(width: 52, alignment: .leading)
            RoundedRectangle(cornerRadius: 2).fill(meeting.color).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title).font(.system(size: 13)).lineLimit(1)
                if !meeting.place.isEmpty {
                    Text(meeting.place).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let url = meeting.joinURL, !past {
                Button("Join") { NSWorkspace.shared.open(url) }.buttonStyle(PillStyle(fill: Palette.outlook))
            }
        }
        .opacity(past ? 0.45 : 1)
        .padding(.horizontal, Metrics.cardPadding)
        .frame(height: 48)
    }
}
