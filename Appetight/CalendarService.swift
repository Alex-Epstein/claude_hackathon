//
//  CalendarService.swift
//  Appetight
//

import Foundation
import EventKit
import Combine

struct CalendarEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    var startString: String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: startDate)
    }
    var endString: String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: endDate)
    }
}

@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()
    private let store = EKEventStore()
    @Published var authorized = false

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17, *) {
                authorized = try await store.requestFullAccessToEvents()
            } else {
                authorized = try await store.requestAccess(to: .event)
            }
        } catch {
            authorized = false
        }
        return authorized
    }

    func todayEvents() -> [CalendarEvent] {
        guard authorized else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { CalendarEvent(title: $0.title ?? "Event", startDate: $0.startDate, endDate: $0.endDate) }
    }

    func addMealEvent(title: String, at date: Date, calories: Int, notes: String) throws {
        guard authorized else { throw CalendarError.notAuthorized }
        let event = EKEvent(eventStore: store)
        event.title = "🥗 \(title)"
        event.startDate = date
        event.endDate = date.addingTimeInterval(30 * 60)
        event.notes = "\(calories) kcal\n\(notes)"
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
    }
}

enum CalendarError: LocalizedError {
    case notAuthorized
    var errorDescription: String? { "Calendar access not granted." }
}
