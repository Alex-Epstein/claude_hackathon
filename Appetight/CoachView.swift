//
//  CoachView.swift
//  Appetight
//
//  Adaptive AI coach. Replies are spoken via ElevenLabs and shown as voice bubbles.
//

import SwiftUI
import AVFoundation
import Combine
import AVFAudio
#if canImport(UIKit)
import UIKit
#endif

// Dismiss keyboard when tapping outside the input
extension View {
    func dismissKeyboardOnTap() -> some View {
        #if canImport(UIKit)
        return self.onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        #else
        return self
        #endif
    }
}

// MARK: - Models

struct CoachMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String
    var audioData: Data? = nil
    var audioError: String? = nil

    enum MessageRole { case user, coach }
}

// MARK: - Audio player

@MainActor
final class AudioPlayerManager: NSObject, ObservableObject {
    @Published var playingId: UUID? = nil

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let boostVolume: Float = 3.0

    override init() {
        super.init()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = boostVolume
    }

    func toggle(data: Data, id: UUID) {
        if playingId == id {
            playerNode.stop()
            engine.stop()
            playingId = nil
            return
        }
        playerNode.stop()
        engine.stop()

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("coach_audio.mp3")
        do {
            try data.write(to: tmp)
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            let file = try AVAudioFile(forReading: tmp)
            try engine.start()
            playerNode.scheduleFile(file, at: nil) {
                Task { @MainActor in self.playingId = nil }
            }
            playerNode.play()
            playingId = id
        } catch {
            playingId = nil
        }
    }
}

// MARK: - Main view

struct CoachView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioManager = AudioPlayerManager()

    @State private var messages: [CoachMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var isUnavailable = false
    @State private var errorDetail: String? = nil
    @State private var hasGreeted = false

    private var userName: String {
        let name = appState.profile?.name ?? ""
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "user" : name
    }

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
                .dismissKeyboardOnTap()
            Divider()
            inputBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { inputFocused = false }
                    .fontWeight(.semibold)
            }
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
                        MessageRow(message: msg, audioManager: audioManager)
                    }
                    if isTyping { TypingBubble().transition(.opacity) }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
                .animation(.easeOut(duration: 0.2), value: messages.count)
                .animation(.easeOut(duration: 0.2), value: isTyping)
            }
            .onChange(of: messages.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: isTyping)      { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask your coach...", text: $inputText, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6), in: .rect(cornerRadius: 20))

            Button { Task { await sendMessage() } } label: {
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
            Text(errorDetail ?? "Unknown error")
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
        await fetchReply(query: text)
    }

    private func fetchReply(query: String) async {
        isTyping = true
        defer { isTyping = false }

        var history: [(role: String, content: String)] = []
        for msg in messages {
            history.append((role: msg.role == .user ? "user" : "assistant", content: msg.text))
        }
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

            let coachMsg = CoachMessage(role: .coach, text: reply)
            messages.append(coachMsg)
            isUnavailable = false
            isTyping = false  // stop typing indicator before waiting on audio

            if let idx = messages.indices.last {
                do {
                    messages[idx].audioData = try await ElevenLabsService.shared.synthesize(text: reply)
                } catch {
                    messages[idx].audioError = error.localizedDescription
                }
            }
        } catch {
            isUnavailable = messages.isEmpty
            errorDetail = error.localizedDescription
        }
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let message: CoachMessage
    @ObservedObject var audioManager: AudioPlayerManager

    var body: some View {
        if message.role == .user {
            userBubble
        } else {
            voiceBubble
        }
    }

    private var userBubble: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 48)
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Brand.green, in: .rect(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
        }
    }

    private var voiceBubble: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Group {
                if let data = message.audioData {
                    playableBubble(data: data)
                } else if let err = message.audioError {
                    errorBubble(err)
                } else {
                    loadingBubble
                }
            }
            Spacer(minLength: 48)
        }
    }

    private func errorBubble(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
            Text(message).font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func playableBubble(data: Data) -> some View {
        let isPlaying = audioManager.playingId == message.id
        return Button {
            audioManager.toggle(data: data, id: message.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(isPlaying ? Color.white.opacity(0.3) : Color.white.opacity(0.2),
                                in: Circle())

                HStack(spacing: 3) {
                    ForEach([0.4, 0.7, 1.0, 0.6, 0.9, 0.5, 0.8, 0.4, 0.7, 0.6], id: \.self) { h in
                        Capsule()
                            .frame(width: 3, height: 24 * h)
                            .foregroundStyle(isPlaying ? Color.white : Color.white.opacity(0.6))
                            .animation(.easeInOut(duration: 0.3).repeatForever().delay(h * 0.1),
                                       value: isPlaying)
                    }
                }
                .frame(height: 24)

                Image(systemName: "waveform")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray4), in: .rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var loadingBubble: some View {
        GeneratingBubble()
    }
}

// MARK: - Generating voice indicator

private struct GeneratingBubble: View {
    @State private var elapsed = 0
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView().tint(Color(.systemGray))
                Text("Generating voice… \(elapsed)s")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(Color(.systemGray3))
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 180)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 18, style: .continuous))
        .task {
            let steps: [(Double, CGFloat)] = [(1,0.15),(1,0.30),(1,0.45),(1,0.58),(1,0.68),(1,0.76),(1,0.82),(1,0.87),(1,0.90)]
            for (delay, target) in steps {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                elapsed += Int(delay)
                progress = target
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                elapsed += 1
            }
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
