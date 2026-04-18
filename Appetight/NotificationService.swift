//
//  NotificationService.swift
//  Appetight
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var authorized: Bool = false

    init() {
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            authorized = granted
            if granted { scheduleMealReminders() }
            return granted
        } catch {
            return false
        }
    }

    func scheduleMealReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["breakfast", "lunch", "dinner"])

        let meals: [(id: String, hour: Int, title: String, body: String)] = [
            ("breakfast", 8, "Appetight — Breakfast", "Don't forget to log breakfast 🥣"),
            ("lunch", 12, "Appetight — Lunch", "Time to log lunch 🥗"),
            ("dinner", 18, "Appetight — Dinner", "Log your dinner to stay on track 🍽️"),
        ]

        for m in meals {
            let content = UNMutableNotificationContent()
            content.title = m.title
            content.body = m.body
            content.sound = .default

            var date = DateComponents()
            date.hour = m.hour
            date.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: m.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Appetight Test"
        content.body = "Notifications are working 🎉"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
