// AppSettings.swift
// Oldies
//
// Persistent app settings. Uses @AppStorage (UserDefaults) for simple values.
// Shared singleton injected via @EnvironmentObject.

import Foundation
import SwiftUI
import Combine

/// AI provider choices.
enum AIProviderType: String, CaseIterable, Identifiable {
    case openAI  = "OpenAI (GPT-4o)"
    case ollama  = "Ollama (lokal)"
    case claude  = "Anthropic Claude"
    var id: String { rawValue }
}

@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: – AI provider
    @AppStorage("ai_provider") var aiProvider: String = AIProviderType.openAI.rawValue
    @AppStorage("openai_api_key") var openAIKey: String = ""
    @AppStorage("openai_model")   var openAIModel: String = "gpt-4o"
    @AppStorage("ollama_url")     var ollamaURL: String = "https://hagstrom.ddns.net/ollama"
    @AppStorage("ollama_model")   var ollamaModel: String = "llava"   // vision-capable
    @AppStorage("claude_api_key") var claudeKey: String = ""
    @AppStorage("claude_model")   var claudeModel: String = "claude-opus-4-6"

    // MARK: – Voice / language
    @AppStorage("tts_voice")          var ttsVoice: String = "sv-SE"   // Swedish
    @AppStorage("speech_language")    var speechLanguage: String = "sv-SE"
    @AppStorage("auto_listen")        var autoListen: Bool = true
    @AppStorage("speak_responses")    var speakResponses: Bool = true

    // MARK: – Camera
    @AppStorage("camera_auto_capture") var autoCaptureOnQuery: Bool = true
    @AppStorage("system_prompt") var systemPrompt: String = """
        Du är Oldies, en hjälpsam AI-assistent i Meta Ray-Ban-glasögon. \
        Du svarar alltid på svenska, kort och koncist. \
        Du kan se vad användaren ser via glasögonkameran och svara på frågor om omgivningen.
        """

    // Computed helper
    var selectedProvider: AIProviderType {
        AIProviderType(rawValue: aiProvider) ?? .openAI
    }

    private init() {}
}
