//
//  PersonaView.swift
//  Appetight
//

import SwiftUI
import SwiftData

struct PersonaView: View {
    @Query private var personas: [UserPersona]

    private var persona: UserPersona? { personas.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = persona, p.totalMealsLogged > 0 {
                    VStack(spacing: 16) {
                        profileHeader(p)
                        macroCard(p)
                        habitsCard(p)
                        favoritesCard(p)
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        "No profile yet",
                        systemImage: "person.crop.circle.dashed",
                        description: Text("Log a few meals and your eating profile will appear here.")
                    )
                }
            }
            .navigationTitle("My Profile")
        }
    }

    private func profileHeader(_ p: UserPersona) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(p.averageDailyCalories))")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Brand.green)
            Text("avg daily kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(p.totalMealsLogged) meals logged")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.gray.opacity(0.06), in: .rect(cornerRadius: 16))
    }

    private func macroCard(_ p: UserPersona) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Avg macros per meal").font(.headline)
            HStack(spacing: 0) {
                macroBar("P", value: p.averageProteinG * 4, color: Brand.green)
                macroBar("C", value: p.averageCarbsG * 4,  color: .orange)
                macroBar("F", value: p.averageFatG * 9,    color: .pink)
            }
            .clipShape(.rect(cornerRadius: 8))
            .frame(height: 24)
            HStack {
                Label("\(Int(p.averageProteinG))g protein", systemImage: "circle.fill")
                    .foregroundStyle(Brand.green)
                Label("\(Int(p.averageCarbsG))g carbs", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
                Label("\(Int(p.averageFatG))g fat", systemImage: "circle.fill")
                    .foregroundStyle(.pink)
            }
            .font(.caption)
            Text("You tend to eat more \(p.dominantMacro).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.gray.opacity(0.06), in: .rect(cornerRadius: 16))
    }

    private func macroBar(_ label: String, value: Double, color: Color) -> some View {
        let total = 2000.0 // rough denominator for visual width
        return color
            .frame(width: max(4, CGFloat(value / total) * 340))
    }

    private func habitsCard(_ p: UserPersona) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eating habits").font(.headline)
            habitRow("Meals per day", value: String(format: "%.1f", p.averageMealsPerDay))
            if let hour = p.peakMealHour {
                habitRow("Peak meal time", value: "\(hour):00")
            }
            if let cuisine = p.topCuisine {
                habitRow("Favorite cuisine", value: cuisine.capitalized)
            }
        }
        .padding()
        .background(.gray.opacity(0.06), in: .rect(cornerRadius: 16))
    }

    private func favoritesCard(_ p: UserPersona) -> some View {
        let top5 = p.favoriteFoods.sorted { $0.value > $1.value }.prefix(5)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Most logged foods").font(.headline)
            ForEach(Array(top5), id: \.key) { food, count in
                HStack {
                    Text(food.capitalized)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.gray.opacity(0.06), in: .rect(cornerRadius: 16))
    }

    private func habitRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.medium)
        }
    }
}