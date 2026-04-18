//
//  DashboardView.swift
//  Appetight
//

import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case today, hungry, gym, friends
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: "Today"
        case .hungry: "Hungry"
        case .gym: "Gym"
        case .friends: "Friends"
        }
    }
    var systemImage: String {
        switch self {
        case .today: "flame.fill"
        case .hungry: "fork.knife"
        case .gym: "dumbbell.fill"
        case .friends: "person.2.fill"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notifications: NotificationService

    @State private var tab: MainTab = .today
    @State private var showingSettings = false
    @State private var showingCamera = false
    @State private var showingVoice = false
    @State private var showingQuickAdd = false

    var body: some View {
        TabView(selection: $tab) {
            todayTab
                .tabItem { Label(MainTab.today.title, systemImage: MainTab.today.systemImage) }
                .tag(MainTab.today)

            hungryTab
                .tabItem { Label(MainTab.hungry.title, systemImage: MainTab.hungry.systemImage) }
                .tag(MainTab.hungry)

            gymTab
                .tabItem { Label(MainTab.gym.title, systemImage: MainTab.gym.systemImage) }
                .tag(MainTab.gym)

            friendsTab
                .tabItem { Label(MainTab.friends.title, systemImage: MainTab.friends.systemImage) }
                .tag(MainTab.friends)
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingCamera) { CameraLoggerView() }
        .sheet(isPresented: $showingVoice) { VoiceLoggerView() }
        .sheet(isPresented: $showingQuickAdd) { QuickAddView() }
    }

    // MARK: - Today tab

    private var todayTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !notifications.authorized {
                        enableNotificationsBanner
                    }

                    summaryCard

                    VStack(spacing: 10) {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Log with Camera", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            showingVoice = true
                        } label: {
                            Label("Log with Voice", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            showingQuickAdd = true
                        } label: {
                            Label("Quick Add", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    mealsList
                }
                .padding()
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var navTitle: String {
        if let name = appState.profile?.name, !name.isEmpty { "Hey \(name)!" }
        else { "Appetight" }
    }

    private var summaryCard: some View {
        let profile = appState.profile
        let totals = appState.todayTotals
        let goal = profile?.calorieGoal ?? 2000
        let macros = TDEE.macros(calories: goal, goal: profile?.goal ?? .maintain)

        return HStack(spacing: 16) {
            CalorieRingView(consumed: totals.calories, goal: goal)
            MacroBarsView(
                protein: totals.protein,
                carbs: totals.carbs,
                fat: totals.fat,
                proteinGoal: macros.protein,
                carbsGoal: macros.carbs,
                fatGoal: macros.fat
            )
        }
        .padding()
        .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    @ViewBuilder
    private var mealsList: some View {
        let meals = appState.todayMeals.sorted { $0.loggedAt > $1.loggedAt }

        if meals.isEmpty {
            VStack(spacing: 6) {
                Text("🍽️").font(.system(size: 40))
                Text("No meals logged yet today")
                    .font(.subheadline).fontWeight(.medium)
                Text("Use camera, voice, or quick add above")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(30)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today's Meals")
                    .font(.headline)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                Divider()

                ForEach(meals) { meal in
                    MealRow(meal: meal) {
                        appState.removeMeal(id: meal.id)
                    }
                    if meal.id != meals.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
        }
    }

    private var enableNotificationsBanner: some View {
        HStack {
            Image(systemName: "bell.fill").foregroundStyle(Brand.orange)
            Text("Enable meal reminders")
                .font(.subheadline)
            Spacer()
            Button("Enable") {
                Task { _ = await notifications.requestPermission() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.orange)
            .controlSize(.small)
        }
        .padding(12)
        .background(Brand.orange.opacity(0.1), in: .rect(cornerRadius: 10))
    }

    // MARK: - Other tabs

    private var hungryTab: some View {
        NavigationStack {
            ScrollView {
                HungryView()
                    .padding()
            }
            .navigationTitle("Find Food")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var gymTab: some View {
        NavigationStack {
            ScrollView {
                GymView()
                    .padding()
            }
            .navigationTitle("Gym")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var friendsTab: some View {
        NavigationStack {
            ScrollView {
                FriendsView()
                    .padding()
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct MealRow: View {
    let meal: MealLog
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(Brand.green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(meal.calories) kcal · P:\(Int(meal.proteinG))g C:\(Int(meal.carbsG))g F:\(Int(meal.fatG))g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(meal.source.label)
                .font(.caption2)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.gray.opacity(0.12), in: .capsule)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var iconName: String {
        switch meal.source {
        case .camera: "camera.fill"
        case .voice: "mic.fill"
        case .restaurant: "fork.knife"
        case .manual: "square.and.pencil"
        }
    }
}
