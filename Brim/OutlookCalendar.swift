import AppKit
import EventKit
import Observation
import SwiftUI

/// Outlook meetings, read through macOS Calendar. An Outlook or Exchange account added in
/// System Settings › Internet Accounts shows up here; when one exists, only its
/// calendars are used.
@Observable @MainActor
final class OutlookCalendar {
    static let outlookID = "com.microsoft.Outlook"

    enum Access { case notAsked, granted, denied }

    struct Meeting: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let place: String
        let color: Color
        let joinURL: URL?
        let isAllDay: Bool
    }

    private(set) var access: Access = .notAsked
    /// The visible month's meetings, sorted by start.
    private(set) var meetings: [Meeting] = []
    private(set) var usesOutlookAccount = false
    private(set) var month = Calendar.current.dateInterval(of: .month, for: .now)!

    private let store = EKEventStore()
    private var timer: Timer?

    init() {
        updateAccess()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        // Once a minute keeps "in 5 min" and "now" honest.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToEvents()
            updateAccess()
            if access == .denied, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
            reload()
        }
    }

    func openOutlook() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.outlookID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    func meetings(on day: Date) -> [Meeting] {
        meetings.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
    }

    /// Today's meetings that haven't ended, all-day ones left out.
    var upcomingToday: [Meeting] {
        meetings(on: .now).filter { !$0.isAllDay && $0.end > .now }
    }

    private func updateAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .notDetermined: access = .notAsked
        default: access = .denied
        }
    }

    func reload() {
        month = Calendar.current.dateInterval(of: .month, for: .now)!
        guard access == .granted else { meetings = []; return }
        let all = store.calendars(for: .event)
        let outlook = all.filter { calendar in
            let source = calendar.source
            let name = (source?.title ?? "").lowercased()
            return source?.sourceType == .exchange
                || ["outlook", "exchange", "office", "microsoft"].contains { name.contains($0) }
        }
        usesOutlookAccount = !outlook.isEmpty
        let predicate = store.predicateForEvents(withStart: month.start, end: month.end, calendars: outlook.isEmpty ? all : outlook)
        meetings = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                Meeting(id: event.calendarItemIdentifier + "\(event.startDate.timeIntervalSince1970)",
                        title: event.title ?? "Untitled",
                        start: event.startDate,
                        end: event.endDate,
                        place: Self.place(of: event),
                        color: Color(cgColor: event.calendar.cgColor),
                        joinURL: Self.joinURL(in: event),
                        isAllDay: event.isAllDay)
            }
    }

    private static func place(of event: EKEvent) -> String {
        let location = event.location ?? ""
        if location.localizedCaseInsensitiveContains("teams") || joinURL(in: event)?.host?.contains("teams") == true { return "Teams" }
        if joinURL(in: event)?.host?.contains("zoom") == true { return "Zoom" }
        return location
    }

    private static let meetingLink = try! NSRegularExpression(
        pattern: #"https://[\w.-]*(teams\.microsoft\.com|teams\.live\.com|zoom\.us|meet\.google\.com|webex\.com)/[^\s<>"]+"#)

    private static func joinURL(in event: EKEvent) -> URL? {
        let haystack = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        let range = NSRange(haystack.startIndex..., in: haystack)
        guard let match = meetingLink.firstMatch(in: haystack, range: range), let r = Range(match.range, in: haystack) else { return nil }
        return URL(string: String(haystack[r]))
    }
}
