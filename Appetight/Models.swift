//
//  Models.swift
//  Appetight
//

import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, other
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive = "very_active"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sedentary: "Sedentary (desk job)"
        case .light: "Light (1–3x/week)"
        case .moderate: "Moderate (3–5x/week)"
        case .active: "Active (6–7x/week)"
        case .veryActive: "Very Active (athlete)"
        }
    }
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case lose, maintain, gain
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lose: "Lose Weight"
        case .maintain: "Maintain"
        case .gain: "Gain Muscle"
        }
    }
    var calorieAdjustment: Int {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 300
        }
    }
    var goalDescription: String {
        switch self {
        case .lose: "lose weight"
        case .maintain: "maintain weight"
        case .gain: "gain muscle"
        }
    }
}

struct UserProfile: Codable, Equatable {
    var name: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var gender: Gender
    var activityLevel: ActivityLevel
    var goal: Goal
    var tdee: Int
    var calorieGoal: Int
}

enum MealSource: String, Codable {
    case manual, camera, voice, restaurant
    var label: String { rawValue.capitalized }
}

struct MealLog: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var loggedAt: Date = Date()
    var source: MealSource
    var restaurantName: String?
}

struct Restaurant: Identifiable, Codable {
    var id: String { placeId }
    let placeId: String
    let name: String
    let vicinity: String
    let rating: Double
    let distanceMeters: Int
    let types: [String]
    var cuisine: String?
    var healthiestOption: HealthyOption?
}

struct HealthyOption: Codable {
    let name: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let description: String
    let whyHealthy: String
}

struct Friend: Codable, Identifiable {
    let id: UUID
    let name: String
    let streakDays: Int
    let caloriesToday: Int
    let goalCalories: Int
    let lastActive: String
}

struct BusyTime: Codable, Identifiable {
    var id: Int { hour }
    let hour: Int
    let busyness: Int
    let label: String
}

struct GymData: Codable {
    let gymName: String
    let busyTimes: [BusyTime]
    let recommendedTime: String
    let recommendedHour: Int
    let reason: String
}
