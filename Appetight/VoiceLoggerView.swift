//
//  VoiceLoggerView.swift
//  Appetight
//

import SwiftUI

struct VoiceLoggerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var speech = SpeechService()

    @State private var analysis: FoodAnalysis?
    @State private var analyzing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(speech.isListening ? Brand.red.opacity(0.2) : Brand.green.opacity(0.12))
                            .frame(width: 160, height: 160)
                            .scaleEffect(speech.isListening ? 1.1 : 1.0)
                            .animation(
                                speech.isListening
                                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                    : .default,
                                value: speech.isListening
                            )
                        Image(systemName: speech.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 60))
                            .foregroundStyle(speech.isListening ? Brand.red : Brand.green)
                    }
                    .padding(.top, 20)

                    Text(speech.isListening ? "Listening..." : "Tap to describe your meal")
                        .font(.headline)

                    if !speech.transcript.isEmpty {
                        Text("\u{201C}\(speech.transcript)\u{201D}")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.gray.opacity(0.08), in: .rect(cornerRadius: 12))
                    }

                    if let speechError = speech.error {
                        errorBanner(speechError)
                    }
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    Button {
                        Task {
                            if speech.isListening { speech.stop() }
                            else { await speech.start() }
                        }
                    } label: {
                        Text(speech.isListening ? "Stop" : "Start Recording")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(speech.isListening ? Brand.red : Brand.green)
                    .controlSize(.large)

                    if !speech.transcript.isEmpty && !speech.isListening && analysis == nil {
                        Button {
                            Task { await analyze() }
                        } label: {
                            HStack {
                                if analyzing { ProgressView().controlSize(.small) }
                                Text(analyzing ? "Analyzing..." : "Analyze")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(analyzing)
                    }

                    if let analysis {
                        resultCard(analysis)
                    }

                    Text("Try: \"I ate a grilled chicken salad with olive oil dressing.\"")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Voice Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        speech.stop()
                        dismiss()
                    }
                }
            }
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
    }

    private func resultCard(_ a: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(a.name).font(.headline)
            Text("\(a.calories) kcal")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Brand.green)
            HStack(spacing: 12) {
                Text("P: \(Int(a.proteinG))g").font(.caption)
                Text("C: \(Int(a.carbsG))g").font(.caption)
                Text("F: \(Int(a.fatG))g").font(.caption)
            }
            .foregroundStyle(.secondary)

            Button {
                appState.addMeal(MealLog(
                    name: a.name,
                    calories: a.calories,
                    proteinG: a.proteinG,
                    carbsG: a.carbsG,
                    fatG: a.fatG,
                    source: .voice
                ))
                dismiss()
            } label: {
                Label("Log It", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Brand.green.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private func analyze() async {
        analyzing = true
        errorMessage = nil
        defer { analyzing = false }
        do {
            analysis = try await AnthropicService.shared.analyzeVoiceLog(transcript: speech.transcript)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
