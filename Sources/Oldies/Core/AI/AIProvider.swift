// AIProvider.swift
// Oldies
//
// Protocol that every AI backend must conform to.
// Supports text completion and vision (image + text).

import Foundation

/// A single message in a conversation.
struct AIMessage: Sendable {
    enum Role: String { case system, user, assistant }
    let role: Role
    let content: String
}

/// Result of streaming – each chunk is a partial text delta.
typealias AIStream = AsyncThrowingStream<String, Error>

/// Protocol every AI provider implements.
protocol AIProvider: Sendable {
    /// Human-readable name shown in Settings.
    var name: String { get }

    /// Non-streaming completion. Returns the full response.
    func complete(
        messages: [AIMessage],
        images: [Data]
    ) async throws -> String

    /// Streaming completion. Yields partial chunks.
    func stream(
        messages: [AIMessage],
        images: [Data]
    ) -> AIStream

    /// Optional: list available models (used in Settings).
    func listModels() async throws -> [String]
}

// Default implementations
extension AIProvider {
    func listModels() async throws -> [String] { [] }
}
