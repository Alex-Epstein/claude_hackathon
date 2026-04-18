//
//  CoachView.swift
//  Appetight
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
    @State private var hasGreeted = false

    private var userName: String {
        let name = appState.profile?.name ?? ""
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "there" : name
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputBar
        }
        .task {
            guard !hasGreeted else { return }
            hasGreeted = true
            await fetchReply(query: "Greet this user by name and give a quick personalized tip based on their eating pattern today.")
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
                    if isTyping { TypingBubble().transition(.opacity) }
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

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    // MARK: - Actions

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(CoachMessage(role: .user, text: text))
        await fetchReply(query: text)
    }

    private func fetchReply(query: String) async {
        isTyping = true
        defer { isTyping = false }

        // Build history in Anthropic format (must alternate user/assistant)
        var history: [(role: String, content: String)] = []
        for msg in messages {
            history.append((role: msg.role == .user ? "user" : "assistant", content: msg.text))
        }
        // If last message isn't user, add the query as user
        if history.last?.role != "user" {
            history.append((role: "user", content: query))
        }

        let ctx = appState.personaContext.isEmpty ? nil : appState.personaContext

        do {
            let reply = try await AnthropicService.shared.coachReply(
                history: history,
                personaContext: ctx,
                userName: userName
            )
            messages.append(CoachMessage(role: .coach, text: reply))
        } catch {
            messages.append(CoachMessage(role: .coach, text: "Sorry, I couldn't connect right now. Try again in a moment."))
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
