import Foundation
import UIKit

/// Sends images and text to an AI backend for analysis.
/// Replace `baseURL` with your own API endpoint.
class AIService: ObservableObject {
    static let shared = AIService()

    // TODO: Replace with your AI API endpoint (e.g. OpenAI, Claude, etc.)
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    // TODO: Store your API key securely (e.g. in Keychain, not here)
    private let apiKey = "YOUR_API_KEY_HERE"

    private init() {}

    // MARK: - Describe image

    /// Sends a photo (JPEG data) to the AI and returns a description.
    func describe(imageData: Data) async throws -> String {
        let base64 = imageData.base64EncodedString()
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text",
                         "text": "Describe what you see in this image in one or two sentences. Be concise."],
                        ["type": "image_url",
                         "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                    ]
                ]
            ],
            "max_tokens": 200
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.badResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        return content ?? "No response."
    }

    // MARK: - Answer question

    /// Sends a text question to the AI and returns an answer.
    func answer(question: String) async throws -> String {
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system",
                 "content": "You are a helpful AI assistant running on Meta Ray-Ban glasses. Be concise."],
                ["role": "user", "content": question]
            ],
            "max_tokens": 300
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.badResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        return content ?? "No response."
    }
}

enum AIError: LocalizedError {
    case badResponse
    var errorDescription: String? { "AI service returned an unexpected response." }
}
