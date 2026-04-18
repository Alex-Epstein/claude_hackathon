//
//  HungryView.swift
//  Appetight
//

import SwiftUI
import CoreLocation
import UIKit

struct HungryView: View {
    @EnvironmentObject var appState: AppState

    @State private var loading = false
    @State private var restaurants: [Restaurant] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("🍽️")
                    .font(.system(size: 40))
                Text("I'm Hungry")
                    .font(.title2.bold())
                Text("We'll scan \(caloriesText) of restaurants near you and surface the healthiest options for your goal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await findFood() }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    Text(loading ? "Finding healthy options..." : "Find Food Near Me")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.orange)
            .controlSize(.large)
            .disabled(loading)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            if !restaurants.isEmpty {
                HStack {
                    Text("Healthy Picks Near You")
                        .font(.headline)
                    Spacer()
                    Button {
                        restaurants = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)

                ForEach(restaurants) { r in
                    RestaurantCard(restaurant: r) { item in
                        logItem(item, restaurant: r)
                    }
                }
            }
        }
    }

    private var caloriesText: String {
        let rem = appState.caloriesRemaining
        if rem < 0 { return "\(-rem) kcal over budget" }
        return "\(rem) kcal remaining"
    }

    private func logItem(_ item: MenuItem, restaurant: Restaurant) {
        appState.addMeal(MealLog(
            name: "\(item.name) (\(restaurant.name))",
            calories: item.calories,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
            source: .restaurant,
            restaurantName: restaurant.name
        ))
        restaurants = []
    }

    private func findFood() async {
        loading = true
        errorMessage = nil
        defer { loading = false }

        do {
            let loc = try await LocationService.shared.requestLocation()
            let places = try await PlacesService.shared.nearbyRestaurants(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude
            )
            if places.isEmpty {
                errorMessage = "No restaurants found nearby."
                return
            }

            let recs = try await AnthropicService.shared.recommendRestaurantMeals(
                restaurants: places.map { ($0.name, $0.types) },
                userGoal: appState.profile?.goal.goalDescription ?? "maintain weight",
                caloriesRemaining: appState.caloriesRemaining
            )

            var enriched = places
            for rec in recs {
                let idx = rec.placeIndex - 1
                guard idx >= 0, idx < enriched.count else { continue }
                enriched[idx].cuisine = rec.cuisine
                enriched[idx].menuItems = rec.menuItems.map { item in
                    MenuItem(
                        name: item.name,
                        calories: item.calories,
                        proteinG: item.proteinG,
                        carbsG: item.carbsG,
                        fatG: item.fatG,
                        description: item.description,
                        whyHealthy: item.whyHealthy,
                        price: item.price
                    )
                }
            }
            restaurants = enriched.filter { !($0.menuItems?.isEmpty ?? true) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    let onLog: (MenuItem) -> Void
    @State private var phoneNumber: String? = nil
    @State private var fetchingPhone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(restaurant.name).font(.subheadline.bold())
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill").font(.caption2)
                        Text(distance)
                        if restaurant.rating > 0 {
                            Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption2)
                            Text(String(format: "%.1f", restaurant.rating))
                        }
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                        Text(cuisine)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.gray.opacity(0.12), in: .capsule)
                    }
                    Button {
                        openMaps()
                    } label: {
                        Label("Directions", systemImage: "map.fill")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button {
                        Task { await callRestaurant() }
                    } label: {
                        if fetchingPhone {
                            ProgressView().controlSize(.mini)
                        } else {
                            Label("Call", systemImage: "phone.fill")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.green)
                    .disabled(fetchingPhone)
                }
            }

            // Menu items
            if let items = restaurant.menuItems, !items.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        menuItemRow(item, rank: idx + 1)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.15)))
    }

    private func menuItemRow(_ item: MenuItem, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if rank == 1 {
                            Image(systemName: "leaf.fill")
                                .font(.caption2)
                                .foregroundStyle(Brand.green)
                        }
                        Text(item.name).font(.caption.weight(.semibold))
                    }
                    Text(item.description).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.price)
                    .font(.caption.bold())
                    .foregroundStyle(Brand.orange)
            }

            HStack {
                Text("\(item.calories) kcal")
                    .font(.caption.bold())
                    .foregroundStyle(item.calories > 0 ? Brand.green : .secondary)
                Text("P:\(Int(item.proteinG))g C:\(Int(item.carbsG))g F:\(Int(item.fatG))g")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button {
                    onLog(item)
                } label: {
                    Label("Log", systemImage: "checkmark").font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(rank == 1 ? Brand.green : .blue)
            }

            Text(item.whyHealthy)
                .font(.caption2).italic().foregroundStyle(Brand.green)
        }
        .padding(8)
        .background(
            rank == 1 ? Brand.green.opacity(0.07) : Color(.systemGroupedBackground),
            in: .rect(cornerRadius: 8)
        )
    }

    private func callRestaurant() async {
        // Use cached number if available
        if let number = phoneNumber ?? restaurant.phoneNumber {
            dial(number)
            return
        }
        fetchingPhone = true
        defer { fetchingPhone = false }
        if let number = await PlacesService.shared.fetchPhoneNumber(placeId: restaurant.placeId) {
            phoneNumber = number
            dial(number)
        }
    }

    private func dial(_ number: String) {
        let digits = number.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel://\(digits)") {
            UIApplication.shared.open(url)
        }
    }

    private func openMaps() {
        let query = restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://maps.apple.com/?q=\(query)") {
            UIApplication.shared.open(url)
        }
    }

    private var distance: String {
        restaurant.distanceMeters < 1000
            ? "\(restaurant.distanceMeters)m"
            : String(format: "%.1fkm", Double(restaurant.distanceMeters) / 1000)
    }
}
