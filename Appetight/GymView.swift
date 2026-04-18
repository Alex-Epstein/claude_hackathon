//
//  GymView.swift
//  Appetight
//

import SwiftUI
import CoreLocation

struct GymView: View {
    @State private var loading = false
    @State private var data: GymData?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🏋️")
                    .font(.system(size: 40))
                Text("Best Gym Time")
                    .font(.title2.bold())
                Text("Find when your nearest gym is least busy — go when it's empty.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await load() }
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    Image(systemName: "dumbbell.fill")
                    Text(loading ? "Analyzing..." : "Find Best Time to Go")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
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

            if let data {
                gymCard(data)
            }
        }
    }

    @ViewBuilder
    private func gymCard(_ d: GymData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dumbbell.fill")
                Text(d.gymName).font(.headline)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.down.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Brand.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go at \(d.recommendedTime)")
                        .fontWeight(.semibold)
                        .foregroundStyle(Brand.green)
                    Text(d.reason).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.green.opacity(0.1), in: .rect(cornerRadius: 10))

            busyChart(d)
        }
        .padding(14)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.15)))
    }

    @ViewBuilder
    private func busyChart(_ d: GymData) -> some View {
        let nowHour = Calendar.current.component(.hour, from: Date())
        let maxBusy = max(d.busyTimes.map(\.busyness).max() ?? 100, 1)

        VStack(alignment: .leading, spacing: 6) {
            Label("Busy times today", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(d.busyTimes) { t in
                    let height = CGFloat(t.busyness) / CGFloat(maxBusy) * 60
                    let isNow = t.hour == nowHour
                    let isRec = t.hour == d.recommendedHour
                    let color: Color =
                        isRec ? Brand.green
                        : isNow ? Brand.blue
                        : t.busyness > 70 ? Brand.red.opacity(0.7)
                        : t.busyness > 40 ? Brand.yellow
                        : .gray.opacity(0.3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(height: max(height, 4))
                }
            }
            .frame(height: 60)

            HStack {
                Text("5 AM").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("12 PM").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("11 PM").font(.caption2).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                legendDot(Brand.green, "Best")
                legendDot(Brand.blue, "Now")
                legendDot(Brand.red.opacity(0.7), "Busy")
            }
            .font(.caption2)
            .padding(.top, 4)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            let loc = try await LocationService.shared.requestLocation()
            let gyms = try await PlacesService.shared.nearbyGyms(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude
            )
            let gymName = gyms.first ?? "Your Local Gym"
            data = try await AnthropicService.shared.gymBusyTimes(gymName: gymName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
