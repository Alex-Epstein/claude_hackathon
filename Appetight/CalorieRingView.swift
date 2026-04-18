//
//  CalorieRingView.swift
//  Appetight
//

import SwiftUI

struct CalorieRingView: View {
    let consumed: Int
    let goal: Int
    var size: CGFloat = 150

    private var pct: Double {
        min(Double(consumed) / Double(max(goal, 1)), 1.0)
    }

    private var ringColor: Color {
        if consumed > goal { return Brand.red }
        if pct > 0.9 { return Brand.orange }
        return Brand.green
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.18), lineWidth: 14)

            Circle()
                .trim(from: 0, to: pct)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: pct)

            VStack(spacing: 0) {
                Text("\(consumed)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(consumed > goal ? Brand.red : Color.primary)
                Text("of \(goal)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct MacroBarsView: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int

    var body: some View {
        VStack(spacing: 10) {
            macroRow("Protein", value: protein, goal: proteinGoal, color: Brand.blue)
            macroRow("Carbs", value: carbs, goal: carbsGoal, color: Brand.yellow)
            macroRow("Fat", value: fat, goal: fatGoal, color: Brand.red.opacity(0.8))
        }
    }

    private func macroRow(_ label: String, value: Double, goal: Int, color: Color) -> some View {
        let pct = min(value / Double(max(goal, 1)), 1.0)
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.caption).fontWeight(.medium)
                Spacer()
                Text("\(Int(value))g / \(goal)g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.12))
                    Capsule().fill(color).frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 6)
        }
    }
}
