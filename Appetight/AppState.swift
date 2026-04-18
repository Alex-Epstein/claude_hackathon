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

    /// Structured eating-pattern summary derived from the meals array.
    /// Injected into both Anthropic food-analysis prompts and Honcho coach queries.
    var personaContext: String {
        guard !meals.isEmpty else { return "" }
        let cal = Calendar.current
        let byDay = Dictionary(grouping: meals) { cal.startOfDay(for: $0.loggedAt) }
        let dailyTotals = byDay.values.map { $0.reduce(0) { $0 + $1.calories } }
        let avgDaily = dailyTotals.reduce(0, +) / max(1, dailyTotals.count)
        let n = Double(meals.count)
        let avgP = meals.reduce(0.0) { $0 + $1.proteinG } / n
        let avgC = meals.reduce(0.0) { $0 + $1.carbsG } / n
        let avgF = meals.reduce(0.0) { $0 + $1.fatG } / n
        let dominant = avgP * 4 >= avgC * 4 && avgP * 4 >= avgF * 9 ? "protein"
                     : avgC * 4 >= avgF * 9 ? "carbs" : "fat"
        var foodCounts: [String: Int] = [:]
        meals.forEach { foodCounts[$0.name.lowercased(), default: 0] += 1 }
        var hourCounts: [Int: Int] = [:]
        meals.map { cal.component(.hour, from: $0.loggedAt) }.forEach { hourCounts[$0, default: 0] += 1 }
        var lines = ["[User Eating Profile]"]
        lines.append("- Avg daily calories: \(avgDaily) kcal")
        lines.append("- Avg macros per meal: \(Int(avgP))g protein, \(Int(avgC))g carbs, \(Int(avgF))g fat")
        lines.append("- Dominant macro tendency: \(dominant)")
        lines.append("- Total meals logged: \(meals.count)")
        if let top = foodCounts.max(by: { $0.value < $1.value })?.key { lines.append("- Most logged food: \(top)") }
        if let peak = hourCounts.max(by: { $0.value < $1.value })?.key { lines.append("- Usually eats around: \(peak):00") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Mutations

    func addMeal(_ meal: MealLog) {
        meals.append(meal)
        if let persona = fetchOrCreatePersona() {
            PersonaEngine.shared.update(persona: persona, with: meal)
        }

        guard let name = profile?.name, !name.isEmpty else { return }
        let summary = "User logged \(meal.name): \(meal.calories) kcal, \(Int(meal.proteinG))g protein, \(Int(meal.carbsG))g carbs, \(Int(meal.fatG))g fat"
        // Every 5 meals, also push the full persona snapshot so Honcho's memory reflects structured stats
        let snapshot: String? = meals.count % 5 == 0 ? personaContext : nil
        Task.detached {
            try? await HonchoService.shared.ensurePeer(name: name)
            try? await HonchoService.shared.logMessage(summary, peerName: name)
            if let snapshot, !snapshot.isEmpty {
                try? await HonchoService.shared.logPersonaSnapshot(snapshot, peerName: name)
            }
        }
    }

    func fetchOrCreatePersona() -> UserPersona? {
        let descriptor = FetchDescriptor<UserPersona>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let new = UserPersona()
        modelContext.insert(new)
        return new
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
