//
//  GymView.swift
//  Appetight
//

import SwiftUI
import CoreLocation

struct GymView: View {
    @State private var loading = false
    @State private var analyzingAll = false
    @State private var gyms: [NearbyGym] = []
    @State private var analyses: [String: GymData] = [:]
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🏋️")
                    .font(.system(size: 40))
                Text("Nearby Gyms")
                    .font(.title2.bold())
                Text("Find gyms near you and see when they're least busy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await loadGyms() }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    Image(systemName: "location.magnifyingglass")
                    Text(loading ? "Searching…" : "Find Gyms Near Me")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(loading || analyzingAll)

            if analyzingAll {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Analyzing busy times for all gyms…")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption).foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
            }

            ForEach(gyms) { gym in
                gymCard(gym)
            }
        }
    }

    // MARK: - Gym card

    @ViewBuilder
    private func gymCard(_ gym: NearbyGym) -> some View {
        let data = analyses[gym.placeId]
        let isPending = analyzingAll && data == nil

        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gym.name).font(.subheadline.bold())
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill").font(.caption2)
                        Text(gym.distanceLabel)
                        if gym.rating > 0 {
                            Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption2)
                            Text(String(format: "%.1f", gym.rating))
                        }
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                    if let price = data?.priceRange {
                        Text(price)
                            .font(.caption2.bold())
                            .foregroundStyle(Brand.green)
                    }
                }
                Spacer()

                if isPending {
                    ProgressView().controlSize(.small)
                }
            }

            // Analysis results
            if let d = data {
                // Best times pills
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark").font(.caption2).foregroundStyle(Brand.green)
                    Text("Best times:").font(.caption2).foregroundStyle(.secondary)
                    ForEach(d.bestTimes.prefix(3), id: \.self) { t in
                        Text(t)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Brand.green.opacity(0.12), in: .capsule)
                            .foregroundStyle(Brand.green)
                    }
                }

                // Reason
                Text(d.reason)
                    .font(.caption).foregroundStyle(.secondary).italic()

                // Chart
                busyChart(d)
            } else if isPending {
                Text("Analyzing busy times…")
                    .font(.caption2).foregroundStyle(.secondary).italic()
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.15)))
    }

    @ViewBuilder
    private func busyChart(_ d: GymData) -> some View {
        let nowHour = Calendar.current.component(.hour, from: Date())
        let maxBusy = max(d.busyTimes.map(\.busyness).max() ?? 100, 1)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(d.busyTimes) { t in
                    let height = CGFloat(t.busyness) / CGFloat(maxBusy) * 50
                    let isNow  = t.hour == nowHour
                    let isRec  = d.bestTimes.contains(t.label)
                    let color: Color =
                        isRec  ? Brand.green
                        : isNow ? Brand.blue
                        : t.busyness > 70 ? Brand.red.opacity(0.7)
                        : t.busyness > 40 ? Brand.yellow
                        : .gray.opacity(0.25)
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(height: max(height, 3))
                }
            }
            .frame(height: 50)

            HStack {
                Text("5 AM").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("12 PM").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("11 PM").font(.caption2).foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                legendDot(Brand.green, "Best")
                legendDot(Brand.blue, "Now")
                legendDot(Brand.red.opacity(0.7), "Busy")
            }.font(.caption2).padding(.top, 2)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    // MARK: - Data loading

    private func loadGyms() async {
        loading = true
        errorMessage = nil
        analyses = [:]
        defer { loading = false }
        do {
            let loc = try await LocationService.shared.requestLocation()
            gyms = try await PlacesService.shared.nearbyGyms(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude
            )
            if gyms.isEmpty {
                errorMessage = "No gyms found nearby."
            } else {
                await analyzeAllGyms()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyzeAllGyms() async {
        analyzingAll = true
        defer { analyzingAll = false }

        // Run all gym analyses in parallel, collect results, then update state once
        let gymSnapshot = gyms
        var results: [(String, GymData)] = []

        await withTaskGroup(of: (String, GymData?).self) { group in
            for gym in gymSnapshot {
                let name = gym.name
                let placeId = gym.placeId
                group.addTask {
                    let data = try? await AnthropicService.shared.gymBusyTimes(gymName: name)
                    return (placeId, data)
                }
            }
            for await (placeId, data) in group {
                if let data { results.append((placeId, data)) }
            }
        }

        for (placeId, data) in results {
            analyses[placeId] = data
        }
    }
}
