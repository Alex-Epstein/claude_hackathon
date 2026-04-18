//
//  UserPersona.swift
//  Appetight
//

import Foundation
import SwiftData

@Model
final class UserPersona {
    var totalMealsLogged: Int = 0
    var averageDailyCalories: Double = 0
    var favoriteFoodsData: Data = Data()        // encoded [String: Int]
    var cuisineTypesData: Data = Data()         // encoded [String: Int]
    var macroProteinTotal: Double = 0
    var macroCarbsTotal: Double = 0
    var macroFatTotal: Double = 0
    var mealTimestamps: [Date] = []
    var dailyCaloriesData: Data = Data()        // encoded [String: Int] date→cals
    var lastUpdated: Date = Date()

    init() {}

    // MARK: - Decoded helpers

    var favoriteFoods: [String: Int] {
        get { decode(favoriteFoodsData) }
        set { favoriteFoodsData = encode(newValue) }
    }

    var cuisineTypes: [String: Int] {
        get { decode(cuisineTypesData) }
        set { cuisineTypesData = encode(newValue) }
    }

    var dailyCalories: [String: Int] {
        get { decode(dailyCaloriesData) }
        set { dailyCaloriesData = encode(newValue) }
    }

    // MARK: - Computed insights

    var averageProteinG: Double {
        totalMealsLogged == 0 ? 0 : macroProteinTotal / Double(totalMealsLogged)
    }

    var averageCarbsG: Double {
        totalMealsLogged == 0 ? 0 : macroCarbsTotal / Double(totalMealsLogged)
    }

    var averageFatG: Double {
        totalMealsLogged == 0 ? 0 : macroFatTotal / Double(totalMealsLogged)
    }

    var topFood: String? {
        favoriteFoods.max(by: { $0.value < $1.value })?.key
    }

    var topCuisine: String? {
        cuisineTypes.max(by: { $0.value < $1.value })?.key
    }

    var averageMealsPerDay: Double {
        guard let first = mealTimestamps.min(),
              let last = mealTimestamps.max() else { return 0 }
        let days = max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1)
        return Double(totalMealsLogged) / Double(days)
    }

    var dominantMacro: String {
        let p = averageProteinG * 4
        let c = averageCarbsG * 4
        let f = averageFatG * 9
        if p >= c && p >= f { return "protein" }
        if c >= p && c >= f { return "carbs" }
        return "fat"
    }

    var peakMealHour: Int? {
        guard !mealTimestamps.isEmpty else { return nil }
        let hours = mealTimestamps.map { Calendar.current.component(.hour, from: $0) }
        return hours.sorted().reduce(into: [Int: Int]()) { $0[$1, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Claude prompt context

    var claudeContext: String {
        guard totalMealsLogged > 0 else { return "" }

        var lines: [String] = ["[User Eating Profile]"]
        lines.append("- Avg daily calories: \(Int(averageDailyCalories)) kcal")
        lines.append("- Avg macros per meal: \(Int(averageProteinG))g protein, \(Int(averageCarbsG))g carbs, \(Int(averageFatG))g fat")
        lines.append("- Dominant macro tendency: \(dominantMacro)")
        lines.append("- Total meals logged: \(totalMealsLogged)")
        if let top = topFood { lines.append("- Most logged food: \(top)") }
        if let cuisine = topCuisine { lines.append("- Favorite cuisine type: \(cuisine)") }
        if let hour = peakMealHour { lines.append("- Usually eats around: \(hour):00") }
        lines.append("Use this to give more accurate portion sizes and personalized nutritional context.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Encode/Decode

    private func encode(_ dict: [String: Int]) -> Data {
        (try? JSONEncoder().encode(dict)) ?? Data()
    }

    private func decode(_ data: Data) -> [String: Int] {
        (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }
}