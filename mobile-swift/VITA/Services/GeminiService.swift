import Foundation

/// Thin REST client for the Gemini generateContent API.
/// Handles multi-turn conversation, system instructions, and JSON serialization.
struct GeminiService: Sendable {

    // MARK: - API Types

    struct Message: Codable, Sendable {
        let role: String   // "user" or "model"
        let parts: [Part]

        struct Part: Codable, Sendable {
            let text: String
        }
    }

    private struct RequestBody: Encodable {
        let systemInstruction: SystemInstruction?
        let contents: [Message]
        let generationConfig: GenerationConfig

        struct SystemInstruction: Encodable {
            let parts: [Message.Part]
        }

        struct GenerationConfig: Encodable {
            let temperature: Double
            let maxOutputTokens: Int
            let topP: Double
        }
    }

    private struct ResponseBody: Decodable {
        let candidates: [Candidate]

        struct Candidate: Decodable {
            let content: Content

            struct Content: Decodable {
                let parts: [Message.Part]
            }
        }
    }

    // MARK: - Errors

    enum GeminiError: Error, LocalizedError {
        case notConfigured
        case emptyResponse
        case httpError(Int, String)
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Gemini API key is not configured. Add it in Settings → Ask VITA AI."
            case .emptyResponse:
                return "Gemini returned an empty response. Try again."
            case .httpError(let code, let body):
                return "Gemini API error \(code): \(body)"
            case .networkError(let message):
                return "Network error: \(message)"
            }
        }
    }

    // MARK: - Chat

    /// Send a multi-turn conversation to Gemini and return the model's text response.
    ///
    /// - Parameters:
    ///   - systemPrompt: Rich context injected as the system instruction (health data, causal analysis).
    ///   - messages: Full conversation history in alternating user/model order.
    ///   - config: Gemini API key and model selection.
    static func chat(
        systemPrompt: String,
        messages: [Message],
        config: GeminiConfig
    ) async throws -> String {
        guard config.isConfigured else { throw GeminiError.notConfigured }

        let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(config.model):generateContent"
        guard let url = URL(string: "\(baseEndpoint)?key=\(config.apiKey)") else {
            throw GeminiError.networkError("Could not construct request URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let primaryBody = buildRequestBody(
            systemPrompt: systemPrompt,
            messages: messages,
            model: config.model,
            forceInlineSystemPrompt: false
        )

        var data: Data
        do {
            data = try await sendRequest(primaryBody, using: request)
        } catch let GeminiError.httpError(code, body)
            where code == 400 && body.localizedCaseInsensitiveContains("Developer instruction is not enabled") {
            // Some models (e.g. Gemma variants) reject system_instruction.
            // Fallback: inline the system prompt as a leading user message.
            let fallbackBody = buildRequestBody(
                systemPrompt: systemPrompt,
                messages: messages,
                model: config.model,
                forceInlineSystemPrompt: true
            )
            data = try await sendRequest(fallbackBody, using: request)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let parsed = try decoder.decode(ResponseBody.self, from: data)

        guard let text = parsed.candidates.first?.content.parts.first?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeminiError.emptyResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func buildRequestBody(
        systemPrompt: String,
        messages: [Message],
        model: String,
        forceInlineSystemPrompt: Bool
    ) -> RequestBody {
        let useSystemInstruction = !forceInlineSystemPrompt && supportsSystemInstruction(model: model)
        let contents: [Message]

        if useSystemInstruction {
            contents = messages
        } else {
            let inlineSystem = Message(
                role: "user",
                parts: [.init(text: "SYSTEM CONTEXT:\n\(systemPrompt)")]
            )
            contents = [inlineSystem] + messages
        }

        return RequestBody(
            systemInstruction: useSystemInstruction ? .init(parts: [.init(text: systemPrompt)]) : nil,
            contents: contents,
            generationConfig: .init(temperature: 0.7, maxOutputTokens: 1024, topP: 0.9)
        )
    }

    private static func supportsSystemInstruction(model: String) -> Bool {
        // Current known exception in this app's model list: Gemma variants.
        !model.lowercased().hasPrefix("gemma")
    }

    private static func sendRequest(_ body: RequestBody, using requestTemplate: URLRequest) async throws -> Data {
        var request = requestTemplate
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw GeminiError.httpError(http.statusCode, errorBody)
        }
        return data
    }
}
