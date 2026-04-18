//
//  SettingsView.swift
//  Appetight
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notifications: NotificationService
    @Environment(\.dismiss) var dismiss

    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                if let p = appState.profile {
                    Section("Profile") {
                        LabeledContent("Name", value: p.name)
                        LabeledContent("Daily goal", value: "\(p.calorieGoal) kcal")
                        LabeledContent("TDEE", value: "\(p.tdee) kcal")
                        LabeledContent("Goal", value: p.goal.label)
                    }
                }

                Section("Notifications") {
                    HStack {
                        Image(systemName: notifications.authorized ? "bell.fill" : "bell.slash")
                            .foregroundStyle(notifications.authorized ? Brand.green : .secondary)
                        Text(notifications.authorized ? "Enabled" : "Disabled")
                        Spacer()
                        if notifications.authorized {
                            Button("Test") { notifications.sendTestNotification() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        } else {
                            Button("Enable") {
                                Task { _ = await notifications.requestPermission() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    if notifications.authorized {
                        Text("Reminders at 8am, 12pm, 6pm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset profile & meals", systemImage: "trash")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Appetight").font(.headline)
                        Text("AI-powered nutrition tracker")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset everything?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    appState.reset()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your profile and all logged meals will be deleted.")
            }
        }
    }
}
