// SpeechRecognizer.swift
// Oldies
//
// Swedish on-device speech-to-text using Apple's Speech framework.
// No data leaves the device — completely private.
//
// Usage:
//   recognizer.startListening()  → publishes transcribedText
//   recognizer.stopListening()

import Foundation
import Speech
import AVFoundation
import SwiftUI

@MainActor
final class SpeechRecognizer: ObservableObject {

    @Published var transcribedText = ""
    @Published var isListening = false
    @Published var error: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        // Swedish locale — falls back to device locale if unavailable
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "sv-SE"))
    }

    // MARK: – Start listening

    func startListening() {
        guard !isListening else { return }

        Task {
            let status = await requestAuthorisation()
            guard status == .authorized else {
                self.error = "Mikrofontillstånd saknas"
                return
            }
            do {
                try self.beginRecording()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: – Stop listening

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask   = nil
        isListening       = false
    }

    // MARK: – Private

    private func beginRecording() throws {
        // Reset any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        // On-device processing for privacy (requires iOS 16+ for Swedish)
        request.requiresOnDeviceRecognition = false

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopListening()
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        transcribedText = ""
    }

    private func requestAuthorisation() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
