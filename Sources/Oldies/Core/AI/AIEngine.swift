// AIEngine.swift
// Oldies
//
// The AIEngine selects the active provider from AppSettings and routes
// requests to OpenAI, Ollama, or Claude. It also maintains conversation
// history so the assistant has context across turns.

import Foundation
import SwiftUI

@MainActor
final class AIEngine: ObservableObject {

    static let shared = AIEngine()

    @Published var isThinking = false
    @Published var lastResponse = ""
    @Published var conversationHistory: [AIMessage] = []

    private var settings: AppSettings { AppSettings.shared }

    private init() {}

    // MARK: – Provider factory

    private func makeProvider() throws -> AIProvider {
        switch settings.selectedProvider {
        case .openAI:
            guard !settings.openAIKey.isEmpty else { throw AIError.noAPIKey }
            return OpenAIProvider(apiKey: settings.openAIKey, model: settings.openAIModel)
        case .ollama:
            return OllamaProvider(baseURL: settings.ollamaURL, model: settings.ollamaModel)
        case .claude:
            guard !settings.claudeKey.isEmpty else { throw AIError.noAPIKey }
            return ClaudeProvider(apiKey: settings.claudeKey, model: settings.claudeModel)
        }
    }

    // MARK: – Ask (non-streaming)

    /// Send a text question, optionally with a captured image from the glasses.
    func ask(
        question: String,
        images: [Data] = [],
        clearHistory: Bool = false
    ) async throws -> String {
        if clearHistory { conversationHistory.removeAll() }

        // Prepend system prompt once at start of conversation
        if conversationHistory.isEmpty {
            conversationHistory.append(.init(role: .system, content: settings.systemPrompt))
        }

        conversationHistory.append(.init(role: .user, content: question))

        isThinking = true
        defer { isThinking = false }

        let provider = try makeProvider()
        let response = try await provider.complete(
            messages: conversationHistory,
            images: images
        )

        conversationHistory.append(.init(role: .assistant, content: response))
        lastResponse = response
        return response
    }

    // MARK: – Streaming ask (yields chunks via AsyncStream)

    func askStreaming(
        question: String,
        images: [Data] = [],
        clearHistory: Bool = false,
        onChunk: @escaping (String) -> Void
    ) async throws {
        if clearHistory { conversationHistory.removeAll() }
        if conversationHistory.isEmpty {
            conversationHistory.append(.init(role: .system, content: settings.systemPrompt))
        }
        conversationHistory.append(.init(role: .user, content: question))

        isThinking = true
        defer { isThinking = false }

        let provider = try makeProvider()
        var fullResponse = ""

        for try await chunk in provider.stream(messages: conversationHistory, images: images) {
            fullResponse += chunk
            onChunk(chunk)
        }

        conversationHistory.append(.init(role: .assistant, content: fullResponse))
        lastResponse = fullResponse
    }

    // MARK: – Describe image

    /// Describe what the glasses camera currently sees.
    func describeScene(imageData: Data) async throws -> String {
        let prompt = "Vad ser du i den här bilden? Beskriv kort på svenska."
        return try await ask(question: prompt, images: [imageData])
    }

    func clearHistory() {
        conversationHistory.removeAll()
    }
}
