import AppKit
import EventKit

struct UpcomingCalendarEvent {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let joinURL: URL?
}

enum CalendarEventState {
    case hidden
    case needsPermission
    case loading
    case denied
    case loaded([UpcomingCalendarEvent])
}

final class CalendarEventProvider {
    private let eventStore = EKEventStore()
    private var storeChangeObserver: NSObjectProtocol?
    var onChange: ((CalendarEventState) -> Void)?

    init() {
        storeChangeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            self?.load()
        }
    }

    deinit {
        if let storeChangeObserver {
            NotificationCenter.default.removeObserver(storeChangeObserver)
        }
    }

    func load() {
        guard UserDefaults.standard.bool(forKey: "showUpcomingEvents") else {
            onChange?(.hidden)
            return
        }

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            fetchEvents()
        case .notDetermined:
            onChange?(.needsPermission)
        case .restricted, .denied, .writeOnly:
            onChange?(.denied)
        @unknown default:
            onChange?(.denied)
        }
    }

    func requestAccess() {
        onChange?(.loading)
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                if granted {
                    self?.fetchEvents()
                } else {
                    self?.onChange?(.denied)
                }
            }
        }
    }

    func open(_ event: UpcomingCalendarEvent) {
        if let joinURL = event.joinURL {
            NSWorkspace.shared.open(joinURL)
            return
        }

        if let calendarURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(
                at: calendarURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    private func fetchEvents() {
        onChange?(.loading)
        let now = Date.now
        let defaults = UserDefaults.standard
        let lookAheadDays = [1, 3, 7, 14, 30].contains(defaults.integer(forKey: "eventLookAheadDays"))
            ? defaults.integer(forKey: "eventLookAheadDays")
            : 14
        let eventCount = min(max(defaults.integer(forKey: "upcomingEventCount"), 1), 5)
        let includeAllDayEvents = defaults.bool(forKey: "includeAllDayEvents")
        let onlyMultipleParticipants = defaults.bool(forKey: "onlyEventsWithMultipleParticipants")
        let start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let end = Calendar.current.date(byAdding: .day, value: lookAheadDays, to: now) ?? now
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)

        let events = eventStore.events(matching: predicate)
            .filter {
                $0.endDate > now
                    && !isDeclined($0)
                    && (includeAllDayEvents || !$0.isAllDay)
                    && (!onlyMultipleParticipants || participantCount(for: $0) >= 2)
            }
            .sorted { $0.startDate < $1.startDate }
            .prefix(eventCount)
            .map { event in
                UpcomingCalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title?.isEmpty == false ? event.title : "Untitled event",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    joinURL: meetingURL(for: event)
                )
            }

        onChange?(.loaded(Array(events)))
    }

    private func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?
            .first(where: { $0.isCurrentUser })?
            .participantStatus == .declined
    }

    private func participantCount(for event: EKEvent) -> Int {
        var participants = Set<String>()

        func add(_ participant: EKParticipant) {
            let url = participant.url
            if !url.absoluteString.isEmpty {
                participants.insert("url:\(url.absoluteString.lowercased())")
            } else if let name = participant.name, !name.isEmpty {
                participants.insert("name:\(name.lowercased())")
            } else {
                participants.insert("object:\(ObjectIdentifier(participant).hashValue)")
            }
        }

        event.attendees?.forEach(add)
        if let organizer = event.organizer {
            add(organizer)
        }
        return participants.count
    }

    private func meetingURL(for event: EKEvent) -> URL? {
        if let url = event.url, isMeetingURL(url) {
            return url
        }

        for text in [event.location, event.notes].compactMap({ $0 }) {
            guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, options: [], range: range) {
                if let url = match.url, isMeetingURL(url) {
                    return url
                }
            }
        }
        return nil
    }

    private func isMeetingURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), url.scheme == "https" else { return false }
        let supportedHosts = [
            "meet.google.com", "zoom.us", "teams.microsoft.com",
            "webex.com", "whereby.com"
        ]
        return supportedHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
