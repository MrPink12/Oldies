// OpenAIProvider.swift
// Oldies
//
// OpenAI provider: GPT-4o with vision support.
// API docs: https://platform.openai.com/docs/api-reference/chat

import Foundation

final class OpenAIProvider: AIProvider, @unchecked Sendable {

    let name = "OpenAI"
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String, model: String = "gpt-4o") {
        self.apiKey = apiKey
        self.model  = model
    }

    // MARK: – Complete

    func complete(messages: [AIMessage], images: [Data]) async throws -> String {
        let body = buildBody(messages: messages, images: images, stream: false)
        let request = buildRequest(body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response)

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    // MARK: – Stream

    func stream(messages: [AIMessage], images: [Data]) -> AIStream {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = buildBody(messages: messages, images: images, stream: true)
                    let request = buildRequest(body: body)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTP(response)

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        if json == "[DONE]" { break }
                        if let data = json.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                           let delta = chunk.choices.first?.delta.content {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: – Models

    func listModels() async throws -> [String] {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        struct ModelList: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        let list = try JSONDecoder().decode(ModelList.self, from: data)
        return list.data.map(\.id).filter { $0.contains("gpt") }.sorted()
    }

    // MARK: – Helpers

    private func buildBody(messages: [AIMessage], images: [Data], stream: Bool) -> [String: Any] {
        var apiMessages: [[String: Any]] = messages.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        // Attach images to last user message
        if !images.isEmpty {
            var contentParts: [[String: Any]] = [
                ["type": "text", "text": messages.last?.content ?? ""]
            ]
            for imageData in images {
                let b64 = imageData.base64EncodedString()
                contentParts.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "auto"]
                ])
            }
            if !apiMessages.isEmpty {
                apiMessages[apiMessages.count - 1]["content"] = contentParts
            }
        }

        return [
            "model": model,
            "messages": apiMessages,
            "stream": stream,
            "max_tokens": 1000
        ]
    }

    private func buildRequest(body: [String: Any]) -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return req
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    // Stream chunk decoding
    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta
        }
        let choices: [Choice]
    }
}

enum AIError: LocalizedError {
    case httpError(Int)
    case noAPIKey
    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP \(code)"
        case .noAPIKey:            return "API-nyckel saknas. Ange den i Inställningar."
        }
    }
}
