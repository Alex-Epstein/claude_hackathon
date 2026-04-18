//
//  FriendsView.swift
//  Appetight
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newFriend: String = ""

    var sortedFriends: [Friend] {
        appState.friends.sorted { $0.streakDays > $1.streakDays }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("👥")
                    .font(.system(size: 40))
                Text("Accountability Circle")
                    .font(.title2.bold())
                Text("Compete with friends to stay on track.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("friend@email.com", text: $newFriend)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(invite)
                Button {
                    invite()
                } label: {
                    Image(systemName: "plus")
                        .padding(6)
                }
                .buttonStyle(.bordered)
            }

            // Me
            myCard

            // Friends
            ForEach(Array(sortedFriends.enumerated()), id: \.element.id) { idx, friend in
                FriendRow(rank: idx, friend: friend)
            }
        }
    }

    private var myCard: some View {
        let calories = appState.todayTotals.calories
        let goal = appState.profile?.calorieGoal ?? 2000
        let pct = min(Double(calories) / Double(max(goal, 1)), 1.0)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("You").fontWeight(.semibold)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").foregroundStyle(Brand.orange)
                    Text("\(appState.streak)d streak").font(.caption)
                        .foregroundStyle(Brand.orange)
                }
            }
            ProgressView(value: pct)
                .tint(Brand.blue)
            Text("\(calories) / \(goal) kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Brand.blue.opacity(0.08), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.blue.opacity(0.3)))
    }

    private func invite() {
        let trimmed = newFriend.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let name = trimmed.components(separatedBy: "@").first ?? trimmed
        appState.addFriend(name: name)
        newFriend = ""
    }
}

struct FriendRow: View {
    let rank: Int
    let friend: Friend

    var pct: Double {
        min(Double(friend.caloriesToday) / Double(max(friend.goalCalories, 1)), 1.0)
    }

    var onTrack: Bool {
        friend.caloriesToday <= friend.goalCalories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if rank == 0 {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                }
                Text(friend.name).fontWeight(.medium)
                Text(friend.lastActive).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "flame").font(.caption2).foregroundStyle(Brand.orange)
                Text("\(friend.streakDays)d")
                    .font(.caption2).foregroundStyle(Brand.orange)
                Text(onTrack ? "on track" : "over")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(onTrack ? Brand.green : Brand.red, in: .capsule)
                    .foregroundStyle(.white)
            }
            ProgressView(value: pct)
                .tint(onTrack ? Brand.green : Brand.red)
            Text("\(friend.caloriesToday) / \(friend.goalCalories) kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.gray.opacity(0.05), in: .rect(cornerRadius: 10))
    }
}
