//
//  TDEE.swift
//  Appetight
//

import Foundation

enum TDEE {
    static func calculateBMR(weightKg: Double, heightCm: Double, age: Int, gender: Gender) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return gender == .male ? base + 5 : base - 161
    }

    static func calculateTDEE(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        gender: Gender,
        activity: ActivityLevel
    ) -> Int {
        let bmr = calculateBMR(weightKg: weightKg, heightCm: heightCm, age: age, gender: gender)
        return Int((bmr * activity.multiplier).rounded())
    }

    static func calorieGoal(tdee: Int, goal: Goal) -> Int {
        max(1200, tdee + goal.calorieAdjustment)
    }

    static func macros(calories: Int, goal: Goal) -> (protein: Int, carbs: Int, fat: Int) {
        let proteinRatio = goal == .lose ? 0.35 : 0.25
        let fatRatio = 0.30
        let carbRatio = 1 - proteinRatio - fatRatio
        let cals = Double(calories)
        return (
            Int((cals * proteinRatio / 4).rounded()),
            Int((cals * carbRatio / 4).rounded()),
            Int((cals * fatRatio / 9).rounded())
        )
    }
}
