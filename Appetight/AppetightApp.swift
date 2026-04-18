//
//  AppetightApp.swift
//  Appetight
//

import SwiftUI
import SwiftData

@main
struct AppetightApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var notifications = NotificationService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(notifications)
                .tint(Brand.green)
        }
        .modelContainer(for: UserPersona.self)
    }
}

enum Brand {
    static let green = Color(red: 0.13, green: 0.77, blue: 0.36)
    static let orange = Color(red: 0.98, green: 0.55, blue: 0.16)
    static let blue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let yellow = Color(red: 0.98, green: 0.75, blue: 0.14)
    static let red = Color(red: 0.94, green: 0.27, blue: 0.27)
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.profile == nil {
            OnboardingView()
        } else {
            DashboardView()
        }
    }
}
