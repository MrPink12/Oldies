// AssistantViewModel.swift
// Oldies
//
// ViewModel for the main assistant screen.
// Coordinates voice input → AI → voice output pipeline.

import Foundation
import SwiftUI
import Combine

@MainActor
final class AssistantViewModel: ObservableObject {

    // MARK: – State
    @Published var messages: [ChatMessage] = []
    @Published var isRecording = false
    @Published var isThinking  = false
    @Published var isSpeaking  = false
    @Published var currentTranscript = ""
    @Published var errorBanner: String?

    // MARK: – Dependencies
    let ai        = AIEngine.shared
    let glasses   = GlassesManager.shared
    let recognizer  = SpeechRecognizer()
    let synthesizer = SpeechSynthesizer()
    private var settings: AppSettings { AppSettings.shared }
    private var cancellables = Set<AnyCancellable>()

    struct ChatMessage: Identifiable {
        enum Sender { case user, assistant }
        let id = UUID()
        let sender: Sender
        var text: String
        let timestamp = Date()
        var imageData: Data?
    }

    init() {
        // Live-update transcript while recording
        recognizer.$transcribedText
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTranscript)

        recognizer.$isListening
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)

        synthesizer.$isSpeaking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeaking)
    }

    // MARK: – Voice interaction

    func toggleRecording() {
        if isRecording {
            finishRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        currentTranscript = ""
        recognizer.startListening()
    }

    private func finishRecording() {
        recognizer.stopListening()
        let question = currentTranscript.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty else { return }
        currentTranscript = ""
        Task { await sendMessage(question) }
    }

    // MARK: – Send message (text or voice)

    func sendMessage(_ text: String, includePhoto: Bool? = nil) async {
        // Decide whether to attach a camera image
        let attachPhoto = includePhoto ?? settings.autoCaptureOnQuery
        var images: [Data] = []

        if attachPhoto {
            if let photoData = glasses.latestPhoto {
                images = [photoData]
            } else if let frame = glasses.latestFrame?.jpegData(compressionQuality: 0.8) {
                // Fall back to last video frame if no dedicated photo yet
                glasses.capturePhoto()
                images = [frame]
            }
        }

        // Add user bubble
        let userMsg = ChatMessage(
            sender: .user,
            text: text,
            imageData: images.first
        )
        messages.append(userMsg)

        // Add thinking placeholder
        var assistantMsg = ChatMessage(sender: .assistant, text: "")
        messages.append(assistantMsg)
        let assistantIdx = messages.count - 1

        isThinking = true
        errorBanner = nil

        do {
            try await ai.askStreaming(question: text, images: images) { [weak self] chunk in
                guard let self else { return }
                Task { @MainActor in
                    self.messages[assistantIdx].text += chunk
                }
            }

            if settings.speakResponses {
                synthesizer.speak(messages[assistantIdx].text)
            }
        } catch {
            messages[assistantIdx].text = "Fel: \(error.localizedDescription)"
            errorBanner = error.localizedDescription
        }

        isThinking = false
    }

    // MARK: – Camera

    func captureAndDescribe() async {
        glasses.capturePhoto()
        // Give SDK a moment to deliver the photo
        try? await Task.sleep(nanoseconds: 800_000_000)

        guard let photoData = glasses.latestPhoto else {
            errorBanner = "Ingen bild från glasögonen"
            return
        }
        await sendMessage("Vad ser du i bilden?", includePhoto: true)
    }

    func clearConversation() {
        messages.removeAll()
        ai.clearHistory()
    }
}
