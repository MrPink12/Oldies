// OllamaProvider.swift
// Oldies
//
// Ollama provider — talks to your local/self-hosted Ollama instance.
// Default: https://hagstrom.ddns.net/ollama
// API docs: https://github.com/ollama/ollama/blob/main/docs/api.md
//
// Uses vision-capable models like `llava` or `moondream` for image analysis.

import Foundation

final class OllamaProvider: AIProvider, @unchecked Sendable {

    let name = "Ollama"
    private let baseURL: URL
    private let model: String

    init(baseURL: String = "https://hagstrom.ddns.net/ollama", model: String = "llava") {
        self.baseURL = URL(string: baseURL)!
        self.model   = model
    }

    // MARK: – Complete (Ollama /api/chat)

    func complete(messages: [AIMessage], images: [Data]) async throws -> String {
        let body = buildBody(messages: messages, images: images, stream: false)
        let url  = baseURL.appendingPathComponent("api/chat")
        var req  = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody   = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)

        struct OllamaResponse: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return decoded.message.content
    }

    // MARK: – Stream

    func stream(messages: [AIMessage], images: [Data]) -> AIStream {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = buildBody(messages: messages, images: images, stream: true)
                    let url  = self.baseURL.appendingPathComponent("api/chat")
                    var req  = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.httpBody   = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, _) = try await URLSession.shared.bytes(for: req)

                    struct Chunk: Decodable {
                        struct Message: Decodable { let content: String? }
                        let message: Message
                        let done: Bool
                    }

                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
                        if let delta = chunk.message.content, !delta.isEmpty {
                            continuation.yield(delta)
                        }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: – List models

    func listModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        let (data, _) = try await URLSession.shared.data(from: url)
        struct TagList: Decodable {
            struct Model: Decodable { let name: String }
            let models: [Model]
        }
        let list = try JSONDecoder().decode(TagList.self, from: data)
        return list.models.map(\.name)
    }

    // MARK: – Helpers

    private func buildBody(messages: [AIMessage], images: [Data], stream: Bool) -> [String: Any] {
        // Ollama chat messages
        var ollamaMessages: [[String: Any]] = messages.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        // Attach base64 images to last user message (Ollama format)
        if !images.isEmpty, !ollamaMessages.isEmpty {
            let b64Images = images.map { $0.base64EncodedString() }
            ollamaMessages[ollamaMessages.count - 1]["images"] = b64Images
        }

        return [
            "model": model,
            "messages": ollamaMessages,
            "stream": stream,
            "options": ["num_predict": 500]
        ]
    }
}
