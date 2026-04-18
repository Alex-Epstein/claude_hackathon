//
//  AppState.swift
//  Appetight
//
//  Central observable store for profile, meals, friends, streak.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var profile: UserProfile? {
        didSet { persistProfile() }
    }
    @Published var meals: [MealLog] = [] {
        didSet { persistMeals() }
    }
    @Published var friends: [Friend] = []
    @Published var streak: Int = 7

    init() {
        loadProfile()
        loadMeals()
        loadFriends()
        loadStreak()
    }

    // MARK: - Derived data

    var todayMeals: [MealLog] {
        let cal = Calendar.current
        return meals.filter { cal.isDateInToday($0.loggedAt) }
    }

    var todayTotals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        todayMeals.reduce((0, 0.0, 0.0, 0.0)) {
            ($0.0 + $1.calories, $0.1 + $1.proteinG, $0.2 + $1.carbsG, $0.3 + $1.fatG)
        }
    }

    var caloriesRemaining: Int {
        guard let p = profile else { return 0 }
        return max(0, p.calorieGoal - todayTotals.calories)
    }

    // MARK: - Mutations

    func addMeal(_ meal: MealLog) {
        meals.append(meal)
    }

    func removeMeal(id: UUID) {
        meals.removeAll { $0.id == id }
    }

    func reset() {
        profile = nil
        meals = []
        UserDefaults.standard.removeObject(forKey: "profile")
        UserDefaults.standard.removeObject(forKey: "meals")
    }

    // MARK: - Persistence

    private func persistProfile() {
        if let p = profile, let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: "profile")
        }
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: "profile"),
              let p = try? JSONDecoder().decode(UserProfile.self, from: data) else { return }
        profile = p
    }

    private func persistMeals() {
        if let data = try? JSONEncoder().encode(meals) {
            UserDefaults.standard.set(data, forKey: "meals")
        }
    }

    private func loadMeals() {
        guard let data = UserDefaults.standard.data(forKey: "meals"),
              let m = try? JSONDecoder().decode([MealLog].self, from: data) else { return }
        meals = m
    }

    private func loadFriends() {
        // Demo friends for the hackathon
        friends = [
            Friend(id: UUID(), name: "Sarah K.", streakDays: 12, caloriesToday: 1820, goalCalories: 1800, lastActive: "2h ago"),
            Friend(id: UUID(), name: "Mike R.", streakDays: 5, caloriesToday: 2100, goalCalories: 2200, lastActive: "30m ago"),
            Friend(id: UUID(), name: "Jess L.", streakDays: 28, caloriesToday: 1650, goalCalories: 1700, lastActive: "5m ago"),
        ]
    }

    private func loadStreak() {
        streak = UserDefaults.standard.integer(forKey: "streak")
        if streak == 0 { streak = 7 }
    }

    func addFriend(name: String) {
        let f = Friend(id: UUID(), name: name, streakDays: 0, caloriesToday: 0, goalCalories: 2000, lastActive: "just joined")
        friends.append(f)
    }
}
