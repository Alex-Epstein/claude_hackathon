//
//  CoachView.swift
//  Appetight
//
//  Adaptive AI coach backed by Honcho memory. Combines Honcho's semantic
//  conversation history with the local personaContext analytics for richer
//  personalisation than either layer alone.
//

import SwiftUI

struct CoachMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String

    enum MessageRole { case user, coach }
}

struct CoachView: View {
    @EnvironmentObject var appState: AppState

    @State private var messages: [CoachMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var isUnavailable = false
    @State private var hasGreeted = false

    private var peerName: String {
        let name = appState.profile?.name ?? ""
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "user" : name
    }

    var body: some View {
        VStack(spacing: 0) {
            if isUnavailable && messages.isEmpty {
                unavailablePlaceholder
            } else {
                messageList
                Divider()
                inputBar
            }
        }
        .task {
            guard !hasGreeted else { return }
            hasGreeted = true
            await fetchCoachResponse(
                query: "Greet this user and give them a personalized tip based on what you know about them so far.",
                logToHoncho: false
            )
        }
    }

    // MARK: - Subviews

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        ChatBubble(message: msg)
                    }
                    if isTyping {
                        TypingBubble()
                            .transition(.opacity)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
                .animation(.easeOut(duration: 0.2), value: messages.count)
                .animation(.easeOut(duration: 0.2), value: isTyping)
            }
            .onChange(of: messages.count) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: isTyping) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask your coach...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6), in: .rect(cornerRadius: 20))

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Brand.green : Color(.systemGray3))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var unavailablePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Coach unavailable")
                .font(.headline)
            Text("Add your Honcho API key in Config.swift to enable the adaptive coach.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    // MARK: - Actions

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(CoachMessage(role: .user, text: text))
        await fetchCoachResponse(query: text, logToHoncho: true)
    }

    private func fetchCoachResponse(query: String, logToHoncho: Bool) async {
        isTyping = true
        defer { isTyping = false }
        do {
            try await HonchoService.shared.ensurePeer(name: peerName)
            if logToHoncho {
                try? await HonchoService.shared.logMessage(query, peerName: peerName)
            }
            let ctx = appState.personaContext.isEmpty ? nil : appState.personaContext
            let reply = try await HonchoService.shared.coachResponse(
                query: query,
                peerName: peerName,
                personaContext: ctx
            )
            messages.append(CoachMessage(role: .coach, text: reply))
            isUnavailable = false
        } catch {
            isUnavailable = true
        }
    }
}

// MARK: - Chat bubble

private struct ChatBubble: View {
    let message: CoachMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isUser { Spacer(minLength: 48) }
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser ? Brand.green : Color(.systemGray5),
                    in: .rect(cornerRadius: 18, style: .continuous)
                )
                .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Typing indicator

private struct TypingBubble: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.25 : 0.8)
                    .opacity(phase == i ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5), in: .rect(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.25)) { phase = (phase + 1) % 3 }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}
