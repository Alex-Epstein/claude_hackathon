//
//  PersonaEngine.swift
//  Appetight
//

import Foundation
import SwiftData

@MainActor
final class PersonaEngine {
    static let shared = PersonaEngine()
    private init() {}

    /// Call this every time a meal is logged
    func update(persona: UserPersona, with meal: MealLog) {
        let dateKey = ISO8601DateFormatter().string(from: meal.loggedAt).prefix(10).description

        // Totals
        persona.totalMealsLogged += 1
        persona.macroProteinTotal += meal.proteinG
        persona.macroCarbsTotal  += meal.carbsG
        persona.macroFatTotal    += meal.fatG
        persona.mealTimestamps.append(meal.loggedAt)

        // Daily calories rollup
        var daily = persona.dailyCalories
        daily[dateKey, default: 0] += meal.calories
        persona.dailyCalories = daily

        // Recompute average daily calories
        let values = daily.values.map { Double($0) }
        persona.averageDailyCalories = values.reduce(0, +) / Double(max(1, values.count))

        // Favorite foods
        var foods = persona.favoriteFoods
        foods[meal.name.lowercased(), default: 0] += 1
        persona.favoriteFoods = foods

        // Cuisine inference (simple keyword matching)
        let cuisine = inferCuisine(from: meal.name)
        if let cuisine {
            var cuisines = persona.cuisineTypes
            cuisines[cuisine, default: 0] += 1
            persona.cuisineTypes = cuisines
        }

        persona.lastUpdated = Date()
    }

    private func inferCuisine(from name: String) -> String? {
        let n = name.lowercased()
        let map: [String: [String]] = [
            "italian":  ["pasta", "pizza", "risotto", "lasagna", "tiramisu"],
            "asian":    ["rice", "noodle", "sushi", "ramen", "stir fry", "pad thai", "dumpling"],
            "mexican":  ["taco", "burrito", "quesadilla", "enchilada", "guacamole"],
            "american": ["burger", "sandwich", "fries", "hot dog", "bbq", "steak"],
            "indian":   ["curry", "dal", "naan", "biryani", "samosa", "tikka"],
            "mediterranean": ["falafel", "hummus", "shawarma", "pita", "gyro"],
            "healthy":  ["salad", "smoothie", "bowl", "wrap", "quinoa", "avocado"]
        ]
        for (cuisine, keywords) in map {
            if keywords.contains(where: { n.contains($0) }) { return cuisine }
        }
        return nil
    }
}