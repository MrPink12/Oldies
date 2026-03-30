// ClaudeProvider.swift
// Oldies
//
// Anthropic Claude provider with vision support.
// API docs: https://docs.anthropic.com/en/api

import Foundation

final class ClaudeProvider: AIProvider, @unchecked Sendable {

    let name = "Claude"
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String, model: String = "claude-opus-4-6") {
        self.apiKey = apiKey
        self.model  = model
    }

    // MARK: – Complete

    func complete(messages: [AIMessage], images: [Data]) async throws -> String {
        let body    = buildBody(messages: messages, images: images, stream: false)
        let request = buildRequest(body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response)

        struct Response: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
            }
            let content: [Content]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }

    // MARK: – Stream

    func stream(messages: [AIMessage], images: [Data]) -> AIStream {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body    = buildBody(messages: messages, images: images, stream: true)
                    let request = buildRequest(body: body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTP(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        if let data = json.data(using: .utf8),
                           let event = try? JSONDecoder().decode(StreamEvent.self, from: data),
                           let text = event.delta?.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: – Helpers

    private func buildBody(messages: [AIMessage], images: [Data], stream: Bool) -> [String: Any] {
        // Separate system messages from conversation
        let systemText = messages.filter { $0.role == .system }.map(\.content).joined(separator: "\n")
        let convMessages = messages.filter { $0.role != .system }

        // Build Anthropic-format messages with optional vision content
        var anthropicMessages: [[String: Any]] = convMessages.enumerated().map { idx, msg in
            // Attach images to the last user message
            if msg.role == .user && idx == convMessages.indices.last && !images.isEmpty {
                var content: [[String: Any]] = [["type": "text", "text": msg.content]]
                for imgData in images {
                    content.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": imgData.base64EncodedString()
                        ]
                    ])
                }
                return ["role": "user", "content": content]
            }
            return ["role": msg.role.rawValue, "content": msg.content]
        }

        var body: [String: Any] = [
            "model": model,
            "messages": anthropicMessages,
            "max_tokens": 1024,
            "stream": stream
        ]
        if !systemText.isEmpty { body["system"] = systemText }
        return body
    }

    private func buildRequest(body: [String: Any]) -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json",         forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,                     forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",               forHTTPHeaderField: "anthropic-version")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    private struct StreamEvent: Decodable {
        struct Delta: Decodable { let text: String? }
        let delta: Delta?
    }
}
