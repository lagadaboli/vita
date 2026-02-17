import Foundation

/// Protocol for local on-device LLM inference.
/// Implementations may use CoreML, MLX, or other on-device runtimes.
public protocol LocalLLMService: Sendable {
    /// Whether the model is loaded and ready for inference.
    var isReady: Bool { get }

    /// Load the model into memory (one-time, on first use).
    func loadModel() async throws

    /// Generate text from a prompt.
    func generate(prompt: String, maxTokens: Int) async throws -> String
}

/// Errors from the LLM service.
public enum LLMError: Error, Sendable {
    case modelNotLoaded
    case modelNotAvailable
    case generationFailed(String)
}
