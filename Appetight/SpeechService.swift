//
//  SpeechService.swift
//  Appetight
//

import Foundation
import Speech
import AVFoundation
import Combine

enum SpeechError: LocalizedError {
    case denied
    case unavailable
    case audioSession(String)

    var errorDescription: String? {
        switch self {
        case .denied: return "Speech recognition permission denied."
        case .unavailable: return "Speech recognition is not available on this device."
        case .audioSession(let m): return "Audio error: \(m)"
        }
    }
}

@MainActor
final class SpeechService: ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var error: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermission() async -> Bool {
        let speechAuth: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechAuth == .authorized else { return false }

        let micAuth: Bool = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        return micAuth
    }

    func start() async {
        guard !isListening else { return }
        error = nil
        transcript = ""

        guard await requestPermission() else {
            error = SpeechError.denied.localizedDescription
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            error = SpeechError.unavailable.localizedDescription
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = SpeechError.audioSession(error.localizedDescription).localizedDescription
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            self.error = SpeechError.audioSession(error.localizedDescription).localizedDescription
            return
        }

        isListening = true

        task = recognizer.recognitionTask(with: request!) { [weak self] result, err in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if err != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
    }
}
